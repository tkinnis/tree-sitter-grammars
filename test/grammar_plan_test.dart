import 'dart:io';

import 'package:checks/checks.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../tool/src/grammar_plan.dart';

const _sha = '0123456789abcdef0123456789abcdef01234567';

GrammarBuild _build({bool generate = false}) {
  final entry = {
    'url': 'https://github.com/example/tree-sitter-x',
    'commit': _sha,
    'license': 'MIT',
    'name': 'x',
    if (generate) 'generate': true,
  };
  return GrammarBuild(name: 'x', entry: entry, metadata: entry, path: '.');
}

void main() {
  late String root;

  setUp(() => root = Directory.systemTemp.createTempSync('plan_test').path);
  tearDown(() => Directory(root).deleteSync(recursive: true));

  void write(String relative) => File(p.join(root, relative))
    ..parent.createSync(recursive: true)
    ..writeAsStringSync('');

  const src = 'build/src/tree-sitter-x/src';

  group('checkSources', () {
    test('accepts a committed parser.c', () {
      write('$src/parser.c');

      checkSources(root, _build());
    });

    test('refuses a grammar with no committed parser.c', () {
      write('$src/grammar.json');

      check(() => checkSources(root, _build()))
          .throws<GrammarPlanException>()
          .has((e) => e.message, 'message')
          .contains('no src/parser.c');
    });

    test('refuses to generate a grammar that commits parser.c', () {
      write('$src/parser.c');
      write('$src/grammar.json');

      check(() => checkSources(root, _build(generate: true)))
          .throws<GrammarPlanException>()
          .has((e) => e.message, 'message')
          .contains('commits src/parser.c, so it must not be generated');
    });

    test('refuses to generate without a grammar.json', () {
      check(() => checkSources(root, _build(generate: true)))
          .throws<GrammarPlanException>()
          .has((e) => e.message, 'message')
          .contains('no src/grammar.json');
    });
  });

  group('scannerSource', () {
    test('is null for a grammar with no scanner', () {
      check(scannerSource(root, _build())).isNull();
    });

    test('is the C scanner when there is one', () {
      write('$src/scanner.c');

      check(scannerSource(root, _build())).equals('$src/scanner.c');
    });

    test('refuses a C++ scanner', () {
      write('$src/scanner.cc');

      check(() => scannerSource(root, _build()))
          .throws<GrammarPlanException>()
          .has((e) => e.message, 'message')
          .contains('C++ scanner');
    });
  });

  group('scannerIncludeDirectory', () {
    test('is src/ when the grammar commits src/tree_sitter/', () {
      write('$src/tree_sitter/parser.h');

      check(scannerIncludeDirectory(root, _build(generate: true))).equals(src);
    });

    test('is the generated directory when it commits no headers', () {
      check(
        scannerIncludeDirectory(root, _build(generate: true)),
      ).equals('build/gen/x');
    });

    test('is src/ for a committed parser whatever its headers', () {
      check(scannerIncludeDirectory(root, _build())).equals(src);
    });
  });

  test('parserAbi reads LANGUAGE_VERSION', () {
    File(
      p.join(root, 'parser.c'),
    ).writeAsStringSync('#include "x.h"\n#define LANGUAGE_VERSION 14\n');

    check(parserAbi(p.join(root, 'parser.c'))).equals(14);
  });
}
