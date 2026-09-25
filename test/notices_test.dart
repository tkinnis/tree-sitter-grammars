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

final _toolchain = Toolchain.parse(
  jsonEncode({
    'treeSitter': {
      'tag': 'v0.27.0',
      'commit': '6070dbfefd326bd735e5683eb128cc1b57dad0c0',
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
  /// header carrying [helperComment].
  (NoticesInput, Map<String, Object?>) fixture({
    String helperComment = '// helpers',
    String parser = 'int parse(void);\n',
    List<String>? extraNotices,
    bool license = true,
  }) {
    write('src/tree-sitter/LICENSE', 'runtime licence\n');
    write('src/tree-sitter/lib/src/unicode/LICENSE', 'Unicode, Inc\n');
    write('src/tree-sitter/lib/src/lib.c', '#include "./parser.c"\n');
    write('src/tree-sitter/lib/src/parser.c', '#include <stdio.h>\n');
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
      toolchain: _toolchain,
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

  test('refuses a compiled copyright comment extraNotices does not name', () {
    final (input, _) = fixture(helperComment: _bsd);

    check(() => thirdPartyNotices(input))
        .throws<NoticesException>()
        .has((e) => e.problems.single, 'problem')
        .contains('src/helper.h carries a copyright comment');
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
        .contains('src/parser.c mentions a copyright outside any comment');
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

  group('copyrightComments', () {
    test('finds block and line comments, never string literals', () {
      check(
        copyrightComments(
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
