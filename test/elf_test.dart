@TestOn('linux')
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../tool/src/build_platform.dart';
import '../tool/src/compiler.dart';
import '../tool/src/elf.dart';
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

/// Whether a `clang` is on `PATH`, which these tests link with as the
/// build does.
final _hasClang = (Platform.environment['PATH'] ?? '')
    .split(':')
    .any((directory) => File(p.join(directory, 'clang')).existsSync());

void main() {
  if (!_hasClang) {
    test('links shared objects with the build\'s flags', () {
      markTestSkipped('no clang on PATH, which a build on Linux needs');
    });
    return;
  }
  late String scratch;
  late Compiler compiler;
  late BuildFlags flags;
  const platform = BuildPlatform.linuxArm64;

  setUpAll(() async {
    scratch = Directory.systemTemp.createTempSync('elf_test').path;
    File(p.join(scratch, 'x.c')).writeAsStringSync(
      '#include <stdlib.h>\n'
      'const void *tree_sitter_x(void) { return malloc(1); }\n',
    );
    compiler = await Compiler.resolve(platform);
    flags = BuildFlags(_toolchain, compiler);
  });

  tearDownAll(() => Directory(scratch).deleteSync(recursive: true));

  /// Compiles and links `x.c` into `lib<name>.so` with the build's grammar
  /// flags and soname, then [extra]; returns its path.
  Future<String> library(String name, {List<String> extra = const []}) async {
    final fileName = platform.libraryFileName(name);
    final object = p.join(scratch, '$name.o');
    final output = p.join(scratch, fileName);
    for (final arguments in [
      [
        ...expandFlags(flags.grammarCompile, scratch),
        p.join(scratch, 'x.c'),
        '-o',
        object,
      ],
      [
        ...flags.grammarLink,
        ...grammarLinkFlags(name, platform: platform),
        ...extra,
        object,
        '-o',
        output,
      ],
    ]) {
      final result = await Process.run(
        compiler.path,
        arguments,
        environment: compilerEnvironment(Platform.environment),
        includeParentEnvironment: false,
      );
      if (result.exitCode != 0) throw StateError('${result.stderr}');
    }
    return output;
  }

  ElfExpectation expecting(String path, {String? soname}) => ElfExpectation(
    path: path,
    soname: soname ?? p.basename(path),
    exportedSymbols: const ['tree_sitter_x'],
  );

  /// A copy of the library at [path] with the 16-bit field at [offset] of
  /// its ELF header set to [value].
  String patched(String path, int offset, int value) {
    final bytes = File(path).readAsBytesSync();
    ByteData.sublistView(bytes).setUint16(offset, value, Endian.little);
    final copy = '$path.$offset.$value';
    File(copy).writeAsBytesSync(bytes);
    return copy;
  }

  test('the compiler records the C library it links against', () {
    check(compiler.libc).isNotNull().startsWith('glibc ');
    check(compiler.libcPath).isNotNull().endsWith('libc.so.6');
    check(p.isAbsolute(compiler.libcPath!)).isTrue();
    check(compiler.sdkPath).isNull();
  });

  test('a shared object linked as the build links grammars passes', () async {
    final path = await library('x');

    check(elfProblems(expecting(path), platform)).isEmpty();
    final image = readElf(File(path).readAsBytesSync());
    check(image.machine).equals(elfMachine(platform));
    check(image.type).equals(elfSharedObject);
    check(image.soname).equals('libx.so');
    check(image.needed).deepEquals(['libc.so.6']);
    check(image.textRelocations).isFalse();
  });

  test('a shared object depending on more than the C library is '
      'refused', () async {
    final path = await library('linked', extra: ['-Wl,--no-as-needed', '-lm']);

    check(
      elfProblems(expecting(path), platform),
    ).deepEquals(['$path: depends on libm.so.6']);
  });

  test('a shared object for another machine is refused', () async {
    final path = patched(await library('x'), 18, 62 /* EM_X86_64 */);

    check(
      elfProblems(expecting(path, soname: 'libx.so'), platform),
    ).deepEquals(['$path: machine 62, not 183']);
  });

  test('an executable is refused', () async {
    final path = patched(await library('x'), 16, 2 /* ET_EXEC */);

    check(
      elfProblems(expecting(path, soname: 'libx.so'), platform),
    ).deepEquals(['$path: type 2, not a shared object']);
  });

  test('a shared object missing an export or named otherwise is '
      'refused', () async {
    final path = await library('x');

    check(
      elfProblems(
        ElfExpectation(
          path: path,
          soname: 'liby.so',
          exportedSymbols: const ['tree_sitter_y'],
        ),
        platform,
      ),
    ).deepEquals(['$path: soname libx.so', '$path: no tree_sitter_y']);
  });

  test('a hidden symbol is no export', () async {
    final path = p.join(scratch, platform.libraryFileName('hidden'));
    final hidden = p.join(scratch, 'hidden.c');
    File(hidden).writeAsStringSync(
      '__attribute__((visibility("hidden"))) '
      'const void *tree_sitter_x(void) { return 0; }\n',
    );
    final result = await Process.run(compiler.path, [
      ...expandFlags(flags.grammarCompile, scratch).where((f) => f != '-c'),
      ...flags.grammarLink.where((f) => !flags.grammarCompile.contains(f)),
      ...grammarLinkFlags('hidden', platform: platform),
      hidden,
      '-o',
      path,
    ], environment: compilerEnvironment(Platform.environment));
    if (result.exitCode != 0) throw StateError('${result.stderr}');

    check(
      elfProblems(expecting(path), platform),
    ).deepEquals(['$path: no tree_sitter_x']);
  });

  test('a file that is no ELF image is refused', () {
    final path = p.join(scratch, 'libnot.so');
    File(path).writeAsStringSync('\x7fELF but nothing more');

    check(elfProblems(expecting(path), platform)).length.equals(1);
  });
}
