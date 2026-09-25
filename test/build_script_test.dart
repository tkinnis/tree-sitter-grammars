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
}
