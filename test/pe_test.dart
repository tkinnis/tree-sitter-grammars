@TestOn('windows')
library;

import 'dart:io';

import 'package:checks/checks.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../tool/src/build_platform.dart';
import '../tool/src/compiler.dart';
import '../tool/src/pe.dart';
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
  late Compiler compiler;
  late BuildFlags flags;
  final platform = BuildPlatform.host;

  setUpAll(() async {
    scratch = Directory.systemTemp.createTempSync('pe_test').path;
    File(p.join(scratch, 'x.c')).writeAsStringSync(
      '#include <stdlib.h>\n'
      '__declspec(dllexport) const void *tree_sitter_x(void) '
      '{ return malloc(1); }\n',
    );
    compiler = await Compiler.resolve(platform);
    flags = BuildFlags(_toolchain, compiler);
  });

  tearDownAll(() => Directory(scratch).deleteSync(recursive: true));

  /// Links `x.c` into `<name>.dll` with the build's grammar flags, then
  /// [extra]; returns its path.
  Future<String> library(String name, {List<String> extra = const []}) async {
    final output = p.join(scratch, '$name.dll');
    final result = await Process.run(compiler.path, [
      ...expandFlags(flags.grammarCompile, scratch).where((f) => f != '-c'),
      ...flags.grammarLink.where((f) => !flags.grammarCompile.contains(f)),
      ...extra,
      p.join(scratch, 'x.c'),
      '-o',
      output,
    ], environment: compilerEnvironment(Platform.environment));
    if (result.exitCode != 0) throw StateError('${result.stderr}');
    return output;
  }

  DllExpectation expecting(String path, {String? name}) => DllExpectation(
    path: path,
    name: name ?? p.basename(path),
    exportedSymbols: const ['tree_sitter_x'],
  );

  test('a DLL linked as the build links grammars passes', () async {
    final path = await library('x');

    check(dllProblems(expecting(path), platform)).isEmpty();
    final image = readPe(File(path).readAsBytesSync());
    check(image.imports).contains('KERNEL32.dll');
    check(image.imports.where((name) => !isSystemImport(name))).isEmpty();
  });

  test('a DLL depending on the Visual C++ runtime is refused', () async {
    final path = await library('dynamic', extra: ['-fms-runtime-lib=dll']);

    check(
      dllProblems(expecting(path), platform),
    ).any((it) => it.contains('depends on VCRUNTIME140.dll'));
  });

  test('a DLL for another machine is refused', () async {
    final other = platform == BuildPlatform.windowsArm64
        ? BuildPlatform.windowsX64
        : BuildPlatform.windowsArm64;
    final path = await library('x');

    check(
      dllProblems(expecting(path), other),
    ).any((it) => it.contains('machine'));
  });

  test('a DLL missing an export or named otherwise is refused', () async {
    final path = await library('x');

    check(
      dllProblems(
        DllExpectation(
          path: path,
          name: 'y.dll',
          exportedSymbols: const ['tree_sitter_y'],
        ),
        platform,
      ),
    ).deepEquals(['$path: export name x.dll', '$path: no tree_sitter_y']);
  });

  test('a file that is no PE image is refused', () {
    final path = p.join(scratch, 'not.dll');
    File(path).writeAsStringSync('MZ but nothing more');

    check(dllProblems(expecting(path), platform)).length.equals(1);
  });
}
