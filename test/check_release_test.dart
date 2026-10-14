import 'dart:convert';
import 'dart:io';

import 'package:checks/checks.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../tool/src/build_platform.dart';
import '../tool/src/build_record.dart' show repositoryUrl;
import 'support/release_fixture.dart';

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

  setUp(
    () => temporary = Directory.systemTemp.createTempSync('check_release_test'),
  );
  tearDown(() => temporary.deleteSync(recursive: true));

  /// Runs `tool/check_release.dart`, copied into a repository of its own,
  /// on an `output/` whose `build_info.json` records the host's platform,
  /// a release built from a dirty working tree, and [toolchain].
  Future<ProcessResult> checkRelease(Map<String, Object?>? toolchain) async {
    final root = temporary.path;
    _copyTools(root);
    final output = p.join(root, 'output');
    File(p.join(output, 'build_info.json'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(
        jsonEncode({
          'release': 'v1.1.0',
          'platform': BuildPlatform.host.id,
          'toolchain': ?toolchain,
          'repository': {
            'url': repositoryUrl,
            'commit': fixtureCommit,
            'dirty': true,
          },
        }),
      );
    File(p.join(output, 'manifest.json')).writeAsStringSync('{}');
    return Process.run(Platform.resolvedExecutable, [
      '--packages=${p.absolute('.dart_tool', 'package_config.json')}',
      p.join(root, 'tool', 'check_release.dart'),
      output,
    ]);
  }

  /// The problems [result] lists, one to a line after its count.
  List<String> problems(ProcessResult result) => [
    for (final line in LineSplitter.split(result.stderr as String))
      if (line.startsWith('  ')) line.trim(),
  ];

  const dirty =
      'build_info.json records the release v1.1.0 as built from a dirty '
      'working tree';

  test('lists every problem of the build record, the toolchain fields a '
      'Linux build records among them, before checking anything '
      'else', () async {
    for (final (toolchain, missing) in [
      (null, ['build_info.json records no toolchain']),
      (
        {...fixtureLinuxToolchain}..remove('linkerPackage'),
        ['build_info.json records no toolchain.linkerPackage'],
      ),
      (
        {...fixtureLinuxToolchain, 'gccRuntime': ''},
        ['build_info.json records no toolchain.gccRuntime'],
      ),
    ]) {
      final result = await checkRelease(toolchain);

      check(because: '$toolchain', result.exitCode).equals(1);
      check(
        because: '$toolchain',
        problems(result),
      ).deepEquals([dirty, if (BuildPlatform.host.isLinux) ...missing]);
    }
    // Each of the three runs starts a Dart that compiles check_release.dart
    // from source, which alone takes most of the default 30 seconds on a
    // slow machine, and more while the rest of the suite runs beside it.
  }, timeout: const Timeout(Duration(minutes: 3)));
}
