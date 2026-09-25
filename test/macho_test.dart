@TestOn('mac-os')
library;

import 'dart:io';

import 'package:checks/checks.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../tool/src/macho.dart';
import '../tool/src/toolchain.dart';

const _toolchain = Toolchain(
  treeSitterTag: 'v0.27.0',
  treeSitterCommit: '6070dbfefd326bd735e5683eb128cc1b57dad0c0',
  treeSitterFilesSha256:
      '8284859e50207152e5df621e49086ea169020c47ef342489f5f8c06b7082f2ea',
  cliVersion: '0.27.0',
  cliAsset: 'tree-sitter-macos-arm64.gz',
  cliSha256: '70f7573b2b2e5371a5b58cc5227d2ad981fd5374596b9874e770af486060774e',
  arch: 'arm64',
  deploymentTarget: '13.0',
);

void main() {
  late String scratch;

  setUpAll(() {
    scratch = Directory.systemTemp.createTempSync('macho_test').path;
    File(
      p.join(scratch, 'x.c'),
    ).writeAsStringSync('const void *tree_sitter_x(void) { return 0; }\n');
  });

  tearDownAll(() => Directory(scratch).deleteSync(recursive: true));

  /// Links `x.c` into a dylib with the build's defaults, except where
  /// [flags] override them; returns its path.
  Future<String> library(
    String name, {
    String arch = 'arm64',
    String minimum = '13.0',
    String installName = '@rpath/libx.dylib',
    List<String> flags = const [],
  }) async {
    final output = p.join(scratch, '$name.dylib');
    final result = await Process.run('xcrun', [
      'clang',
      '-dynamiclib',
      '-arch',
      arch,
      '-mmacosx-version-min=$minimum',
      '-Wl,-install_name,$installName',
      ...flags,
      p.join(scratch, 'x.c'),
      '-o',
      output,
    ]);
    if (result.exitCode != 0) throw StateError('${result.stderr}');
    return output;
  }

  Future<List<String>> problems(String path) => libraryProblems(
    LibraryExpectation(
      path: path,
      installName: '@rpath/libx.dylib',
      exportedSymbols: const ['_tree_sitter_x'],
    ),
    _toolchain,
  );

  test('a library built as the toolchain says has no problems', () async {
    check(await problems(await library('good'))).isEmpty();
  });

  test('another deployment target is reported', () async {
    final path = await library('minos', minimum: '14.0');

    check(await problems(path)).deepEquals(['$path: minos [14.0]']);
  });

  test('another architecture is reported', () async {
    final path = await library('intel', arch: 'x86_64');

    check(await problems(path)).contains('$path: architectures x86_64');
  });

  test('another install name is reported', () async {
    final path = await library('named', installName: '/usr/local/libx.dylib');

    check(
      await problems(path),
    ).deepEquals(['$path: install name /usr/local/libx.dylib']);
  });

  test('a dependency beyond libSystem is reported', () async {
    final path = await library(
      'linked',
      flags: ['-framework', 'CoreFoundation'],
    );

    check(await problems(path)).single.startsWith('$path: depends on [');
  });

  test('a missing export is reported', () async {
    final path = await library('hidden', flags: ['-fvisibility=hidden']);

    check(await problems(path)).deepEquals(['$path: no _tree_sitter_x']);
  });
}
