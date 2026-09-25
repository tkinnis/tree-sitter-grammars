import 'dart:convert';
import 'dart:io';

import 'package:checks/checks.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../tool/src/grammar_plan.dart';
import '../tool/src/manifest.dart';

const _commit = '0123456789abcdef0123456789abcdef01234567';
const _sourceCommit = 'fedcba9876543210fedcba9876543210fedcba98';

GrammarBuild _build(Map<String, Object?> pins) {
  final entry = {
    'url': 'https://github.com/example/tree-sitter-x',
    'commit': _commit,
    'license': 'MIT',
    ...pins,
  };
  return GrammarBuild(
    name: 'x',
    entry: entry,
    metadata: const {
      'scope': 'source.x',
      'file-types': ['x']
    },
    path: 'grammars/x',
  );
}

void main() {
  late String root;

  setUp(() => root = Directory.systemTemp.createTempSync('manifest_test').path);
  tearDown(() => Directory(root).deleteSync(recursive: true));

  test('a committed parser names its pin, deploy source and licence', () {
    final entry =
        grammarEntry(root, _build({'sourceCommit': _sourceCommit}), 14);

    check(entry['source']).isA<Map<String, Object?>>().deepEquals({
      'url': 'https://github.com/example/tree-sitter-x',
      'commit': _commit,
      'sourceCommit': _sourceCommit,
      'path': 'grammars/x',
      'parser': 'committed',
      'abi': 14,
      'license': 'MIT',
    });
    check(sourceProblems(entry['source'])).isEmpty();
  });

  test('a generated parser says so and names no deploy source', () {
    final source = grammarEntry(root, _build({'generate': true}), 15)['source']
        as Map<String, Object?>;

    check(source['parser']).equals('generated');
    check(source.containsKey('sourceCommit')).isFalse();
    check(sourceProblems(source)).isEmpty();
  });

  test('a malformed source is reported field by field', () {
    check(sourceProblems({
      'url': 'git@github.com:example/tree-sitter-x',
      'commit': _commit.substring(0, 12),
      'path': '',
      'parser': 'regenerated',
      'abi': 16,
      'license': '',
      'note': 'x',
    })).deepEquals([
      'source.url must be an https URL',
      'source.commit must be 40 lowercase hex digits',
      'source.path must be a path',
      'source.parser must be "committed" or "generated"',
      'source.abi must be a language ABI from 13 to 15',
      'source.license must name a licence',
      'source has unknown field "note"',
    ]);
  });

  group('validate_manifest.dart', () {
    Future<ProcessResult> validate(Map<String, Object?> manifest) {
      final file = File(p.join(root, 'manifest.json'))
        ..writeAsStringSync(jsonEncode(manifest));
      return Process.run(Platform.resolvedExecutable, [
        '--packages=${p.absolute('.dart_tool', 'package_config.json')}',
        p.join('tool', 'validate_manifest.dart'),
        file.path,
      ]);
    }

    test('passes a compiled grammar that names its source', () async {
      final result = await validate({'x': grammarEntry(root, _build({}), 15)});

      check(result.exitCode).equals(0);
    });

    test('fails a compiled grammar with no source', () async {
      final result = await validate({
        'x': {...grammarEntry(root, _build({}), 15)}..remove('source'),
      });

      check(result.exitCode).equals(1);
      check(result.stdout as String)
          .contains('x: Missing required field "source"');
    });
  });
}
