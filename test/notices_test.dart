import 'dart:convert';
import 'dart:io';

import 'package:checks/checks.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../tool/src/grammar_plan.dart';
import '../tool/src/notices.dart';
import '../tool/src/query_provenance.dart';
import '../tool/src/toolchain.dart';

const _pin = '0123456789abcdef0123456789abcdef01234567';

/// The toolchain, with [extraNotices] as the runtime's.
Toolchain _toolchain({List<String>? extraNotices}) => Toolchain.parse(
  jsonEncode({
    'treeSitter': {
      'tag': 'v0.27.0',
      'commit': '6070dbfefd326bd735e5683eb128cc1b57dad0c0',
      'extraNotices': ?extraNotices,
    },
    'treeSitterCli': {
      'version': '0.27.0',
      'asset': 'tree-sitter-macos-arm64.gz',
      'sha256':
          '70f7573b2b2e5371a5b58cc5227d2ad981fd5374596b9874e770af486060774e',
    },
    'macos': {'arch': 'arm64', 'deploymentTarget': '13.0'},
  }),
);

const _bsd =
    '/*\n * Copyright (c) 1990 Regents of the University of California.\n */';

void main() {
  late Directory temporary;

  setUp(() => temporary = Directory.systemTemp.createTempSync('notices_test'));
  tearDown(() => temporary.deleteSync(recursive: true));

  String path(String relative) => p.join(temporary.path, relative);

  void write(String relative, String text) => File(path(relative))
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(text);

  /// A runtime and one grammar, `tree-sitter-x`, whose scanner includes a
  /// header carrying [helperComment]; the runtime's `lib.c` includes a
  /// `parser.c` holding [runtimeParser].
  (NoticesInput, Map<String, Object?>) fixture({
    String helperComment = '// helpers',
    String parser = 'int parse(void);\n',
    List<String>? extraNotices,
    bool license = true,
    String runtimeParser = '#include <stdio.h>\n',
    List<String>? runtimeExtraNotices,
  }) {
    write('src/tree-sitter/LICENSE', 'runtime licence\n');
    write('src/tree-sitter/lib/src/unicode/LICENSE', 'Unicode, Inc\n');
    write(
      'src/tree-sitter/lib/src/unicode/utf8.h',
      '// Copyright (c) Unicode, Inc. All rights reserved.\n',
    );
    write(
      'src/tree-sitter/lib/src/lib.c',
      '#include "./parser.c"\n#include "unicode/utf8.h"\n',
    );
    write('src/tree-sitter/lib/src/parser.c', runtimeParser);
    if (license) write('src/tree-sitter-x/LICENSE', 'grammar licence\n');
    write('src/tree-sitter-x/src/parser.c', parser);
    write('src/tree-sitter-x/src/scanner.c', '#include "helper.h"\n');
    write('src/tree-sitter-x/src/helper.h', '$helperComment\n');
    write(
      'src/tree-sitter-x/src/tree_sitter/parser.h',
      '// Copyright tree-sitter\n',
    );
    final entry = <String, Object?>{
      'url': 'https://github.com/example/tree-sitter-x',
      'commit': _pin,
      'license': 'MIT',
      'extraNotices': ?extraNotices,
      'name': 'x',
    };
    final input = NoticesInput(
      toolchain: _toolchain(extraNotices: runtimeExtraNotices),
      runtimeDirectory: path('src/tree-sitter'),
      entries: [entry],
      builds: [
        GrammarBuild(name: 'x', entry: entry, metadata: entry, path: '.'),
      ],
      sourceRoot: path('src'),
      provenance: (
        entries: {
          'queries/x/tags.scm': const QueryProvenance(
            origin: QueryOrigin.here,
            changed: false,
          ),
        },
        problems: const [],
      ),
      apacheLicense: 'Apache License text\n',
      ownLicense: 'own licence\n',
    );
    return (input, entry);
  }

  test('reproduces every licence and lists every query file', () {
    final (input, _) = fixture();

    final notices = thirdPartyNotices(input);

    for (final text in [
      'runtime licence',
      'Unicode, Inc',
      'grammar licence',
      '`libx.dylib` is compiled from https://github.com/example/tree-sitter-x '
          'at $_pin',
      '- `x/tags.scm`',
      'own licence',
      'Apache License text',
    ]) {
      check(notices).contains(text);
    }
  });

  test('refuses a grammar with no licence file at its root', () {
    final (input, _) = fixture(license: false);

    check(() => thirdPartyNotices(input))
        .throws<NoticesException>()
        .has((e) => e.problems, 'problems')
        .contains('tree-sitter-x: no licence file at its root');
  });

  test('refuses a licence file that is not UTF-8 text', () {
    final (input, _) = fixture();
    File(path('src/tree-sitter-x/LICENSE')).writeAsBytesSync(
      latin1.encode('Copyright (c) 2021 Patrick F\xf6rster\n'),
    );

    check(() => thirdPartyNotices(input))
        .throws<NoticesException>()
        .has((e) => e.problems, 'problems')
        .contains('tree-sitter-x: LICENSE is not UTF-8 text');
  });

  test('refuses a compiled copyright comment extraNotices does not name', () {
    final (input, _) = fixture(helperComment: _bsd);

    check(() => thirdPartyNotices(input))
        .throws<NoticesException>()
        .has((e) => e.problems.single, 'problem')
        .contains('src/helper.h carries a licence comment');
  });

  test('reproduces a copyright comment extraNotices names', () {
    final (input, _) = fixture(
      helperComment: _bsd,
      extraNotices: ['src/helper.h'],
    );

    check(thirdPartyNotices(input)).contains(_bsd);
  });

  test('refuses a copyright mentioned outside any comment', () {
    final (input, _) = fixture(parser: 'const char *s = "Copyright";\n');

    check(() => thirdPartyNotices(input))
        .throws<NoticesException>()
        .has((e) => e.problems.single, 'problem')
        .contains('src/parser.c mentions a licence outside any comment');
  });

  test('refuses a copyright outside the comments of a file named in '
      'extraNotices', () {
    final (input, _) = fixture(
      parser:
          '/* Copyright (c) A */\n'
          'const char *s = "Copyright (c) B, all rights reserved";\n',
      extraNotices: ['src/parser.c'],
    );

    check(() => thirdPartyNotices(input))
        .throws<NoticesException>()
        .has((e) => e.problems.single, 'problem')
        .contains('src/parser.c mentions a licence outside any comment');
  });

  for (final (label, comment) in [
    ('an SPDX identifier', '// SPDX-License-Identifier: GPL-3.0-only'),
    ('a public-domain dedication', '// "License": Public Domain'),
    ('a permission grant', '/* Permission is hereby granted, free */'),
    ('all rights reserved', '/* All rights reserved. */'),
    ('a copyright sign', '// \u00a9 2020 Someone'),
    ('a (c) notice', '/* (c) 2020 Someone */'),
  ]) {
    test('refuses $label in a compiled comment extraNotices does not name', () {
      final (input, _) = fixture(helperComment: comment);

      check(() => thirdPartyNotices(input))
          .throws<NoticesException>()
          .has((e) => e.problems.single, 'problem')
          .contains('src/helper.h carries a licence comment');
    });
  }

  test('reads (c) outside a comment as code, not a notice', () {
    final (input, _) = fixture(
      parser: 'int f(int c) { return iswspace(c) || (c) == 0; }\n',
    );

    check(thirdPartyNotices(input)).contains('grammar licence');
  });

  test('reproduces a run of line comments as one notice', () {
    const header =
        '// "License": Public Domain\n'
        '// I place this file into the public domain.\n'
        '  // Consider it an example.';
    final (input, _) = fixture(
      helperComment: '$header\n\n// unrelated',
      extraNotices: ['src/helper.h'],
    );

    final notices = thirdPartyNotices(input);

    check(notices).contains('```text\n$header\n```');
    check(notices).not((it) => it.contains('unrelated'));
  });

  test('reproduces a NOTICE file at a grammar\'s root', () {
    final (input, _) = fixture();
    write('src/tree-sitter-x/NOTICE', 'x includes software by Someone\n');

    check(
      thirdPartyNotices(input),
    ).contains('#### NOTICE\n\n```text\nx includes software by Someone\n```');
  });

  test('refuses a NOTICE file that is not UTF-8 text', () {
    final (input, _) = fixture();
    File(
      path('src/tree-sitter-x/NOTICE.txt'),
    ).writeAsBytesSync(latin1.encode('F\xf6rster\n'));

    check(() => thirdPartyNotices(input))
        .throws<NoticesException>()
        .has((e) => e.problems, 'problems')
        .contains('tree-sitter-x: NOTICE.txt is not UTF-8 text');
  });

  test('refuses a runtime licence comment the toolchain does not name', () {
    final (input, _) = fixture(runtimeParser: '// "License": Public Domain\n');

    check(() => thirdPartyNotices(input))
        .throws<NoticesException>()
        .has((e) => e.problems.single, 'problem')
        .contains(
          'tree-sitter: lib/src/parser.c carries a licence comment; name it '
          'in toolchain.json',
        );
  });

  test('reproduces a runtime licence comment the toolchain names', () {
    final (input, _) = fixture(
      runtimeParser: '// "License": Public Domain\n',
      runtimeExtraNotices: ['lib/src/parser.c'],
    );

    check(thirdPartyNotices(input))
      ..contains('### lib/src/parser.c')
      ..contains('```text\n// "License": Public Domain\n```');
  });

  test('refuses an extraNotices entry naming no copyrighted source', () {
    final (input, _) = fixture(extraNotices: ['src/helper.h']);

    check(() => thirdPartyNotices(input)).throws<NoticesException>();
  });

  test('refuses provenance problems', () {
    final (input, _) = fixture();

    check(
      () => thirdPartyNotices(
        NoticesInput(
          toolchain: input.toolchain,
          runtimeDirectory: input.runtimeDirectory,
          entries: input.entries,
          builds: input.builds,
          sourceRoot: input.sourceRoot,
          provenance: (
            entries: const {},
            problems: const ['queries/x/tags.scm: no entry'],
          ),
          apacheLicense: input.apacheLicense,
          ownLicense: input.ownLicense,
        ),
      ),
    ).throws<NoticesException>();
  });

  group('licenseComments', () {
    test('finds block and line comments, never string literals', () {
      check(
        licenseComments(
          'char *a = "/* Copyright */";\n'
          '/* Copyright A */\n'
          "char b = '\"';\n"
          '// copyright B\n'
          '/* nothing */\n',
        ),
      ).deepEquals(['/* Copyright A */', '// copyright B']);
    });
  });

  group('includedFiles', () {
    test('follows quoted and angle includes to files under the root', () {
      write(
        'r/src/a.c',
        '#include "b.h"\n#include <c.h>\n#include <stdio.h>\n',
      );
      write('r/src/b.h', '#include "../common/d.h"\n');
      write('r/common/d.h', '');
      write('r/include/c.h', '');

      check(
        includedFiles(path('r'), ['src/a.c'], ['include']),
      ).deepEquals(['common/d.h', 'include/c.h', 'src/a.c', 'src/b.h']);
    });

    test('compiledSources leaves out src/tree_sitter/', () {
      write('r/src/parser.c', '#include "tree_sitter/parser.h"\n');
      write('r/src/tree_sitter/parser.h', '');

      check(compiledSources(path('r'), 'src')).deepEquals(['src/parser.c']);
    });
  });
}
