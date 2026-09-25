import 'dart:io';

import 'package:checks/checks.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Copies this repository's `tool/` into [root].
void _copyTools(String root) {
  for (final entity in Directory('tool').listSync(recursive: true)) {
    if (entity is! File) continue;
    final copy = File(p.join(root, entity.path));
    copy.parent.createSync(recursive: true);
    entity.copySync(copy.path);
  }
}

Future<ProcessResult> _build(String root, List<String> arguments) =>
    Process.run(Platform.resolvedExecutable, [
      '--packages=${p.absolute('.dart_tool', 'package_config.json')}',
      p.join(root, 'tool', 'build_tree_sitter_grammars.dart'),
      ...arguments,
    ]);

void main() {
  late Directory temporary;

  setUp(() => temporary = Directory.systemTemp.createTempSync('build_test'));
  tearDown(() => temporary.deleteSync(recursive: true));

  test('a build that fails leaves no output/', () async {
    final root = temporary.path;
    _copyTools(root);
    File(p.join(root, 'queries', 'c', 'highlights.scm'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('(identifier) @variable\n');
    File(p.join(root, 'tool', 'query_provenance.json')).writeAsStringSync('{}');
    File(p.join(root, 'output', 'manifest.json'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('{}');

    final result = await Process.run(Platform.resolvedExecutable, [
      '--packages=${p.absolute('.dart_tool', 'package_config.json')}',
      p.join(root, 'tool', 'build_tree_sitter_grammars.dart'),
    ]);

    check(result.exitCode).equals(1);
    check(
      result.stderr as String,
    ).contains('queries/c/highlights.scm: no entry');
    check(Directory(p.join(root, 'output')).existsSync()).isFalse();
  });

  for (final arguments in [
    ['--publish'],
    ['--dry-run'],
    ['--release=v1.1.0', '--dry-run', '--publish'],
    ['--release=v1.1.0', '--publish', '--publish'],
    ['--sources='],
  ]) {
    test('refuses ${arguments.join(' ')}', () async {
      _copyTools(temporary.path);

      final result = await _build(temporary.path, arguments);

      check(result.exitCode).equals(64);
      check(result.stderr as String).contains('usage:');
    });
  }

  test('refuses source bundles inside output/, which it deletes', () async {
    final root = temporary.path;
    _copyTools(root);
    final bundles = Directory(p.join(root, 'output', 'sources'))
      ..createSync(recursive: true);

    final result = await _build(root, ['--sources=${bundles.path}']);

    check(result.exitCode).equals(1);
    check(result.stderr as String).contains('is inside output/');
    check(bundles.existsSync()).isTrue();
  });
}
