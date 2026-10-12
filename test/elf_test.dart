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

/// A crafted shared object for arm64 holding only a string table and a
/// version-needed section that lists, by file, the versions [needs]
/// names, laid out as a linker lays them out.
Uint8List _craftedElf(Map<String, List<String>> needs) {
  final strings = BytesBuilder()..addByte(0);
  int string(String text) {
    final at = strings.length;
    strings
      ..add(text.codeUnits)
      ..addByte(0);
    return at;
  }

  final need = BytesBuilder();
  final files = needs.entries.toList();
  for (final (index, MapEntry(key: file, value: versions)) in files.indexed) {
    final entry = ByteData(16 + 16 * versions.length)
      ..setUint16(0, 1, Endian.little) // vn_version
      ..setUint16(2, versions.length, Endian.little) // vn_cnt
      ..setUint32(4, string(file), Endian.little) // vn_file
      ..setUint32(8, 16, Endian.little) // vn_aux
      ..setUint32(
        12,
        index == files.length - 1 ? 0 : 16 + 16 * versions.length,
        Endian.little,
      ); // vn_next
    for (final (at, version) in versions.indexed) {
      final aux = 16 + 16 * at;
      entry
        ..setUint16(aux + 6, at + 2, Endian.little) // vna_other
        ..setUint32(aux + 8, string(version), Endian.little) // vna_name
        ..setUint32(
          aux + 12,
          at == versions.length - 1 ? 0 : 16,
          Endian.little,
        ); // vna_next
    }
    need.add(entry.buffer.asUint8List());
  }
  int aligned(int offset) => (offset + 7) & ~7;
  final stringsAt = 64;
  final needAt = aligned(stringsAt + strings.length);
  final sectionsAt = aligned(needAt + need.length);
  final bytes = Uint8List(sectionsAt + 3 * 64)
    ..setAll(0, [0x7f, 0x45, 0x4c, 0x46, 2, 1, 1])
    ..setAll(stringsAt, strings.toBytes())
    ..setAll(needAt, need.toBytes());
  final data = ByteData.sublistView(bytes)
    ..setUint16(16, elfSharedObject, Endian.little)
    ..setUint16(18, 183 /* EM_AARCH64 */, Endian.little)
    ..setUint64(0x28, sectionsAt, Endian.little)
    ..setUint16(0x34, 64, Endian.little)
    ..setUint16(0x3a, 64, Endian.little)
    ..setUint16(0x3c, 3, Endian.little);
  void section(int index, int type, int offset, int size, int link) {
    final header = sectionsAt + 64 * index;
    data
      ..setUint32(header + 4, type, Endian.little)
      ..setUint64(header + 24, offset, Endian.little)
      ..setUint64(header + 32, size, Endian.little)
      ..setUint32(header + 40, link, Endian.little);
  }

  section(1, 3 /* SHT_STRTAB */, stringsAt, strings.length, 0);
  section(2, 0x6ffffffe /* SHT_GNU_verneed */, needAt, need.length, 1);
  return bytes;
}

void main() {
  group('the glibc a library needs', () {
    final crafted = _craftedElf({
      'libc.so.6': ['GLIBC_2.17', 'GLIBC_2.34', 'GLIBC_PRIVATE'],
      'ld-linux-aarch64.so.1': ['GLIBC_2.9'],
    });

    test('is read from every entry of the version-needed section', () {
      check(readElf(crafted).versionsNeeded).deepEquals({
        'libc.so.6': ['GLIBC_2.17', 'GLIBC_2.34', 'GLIBC_PRIVATE'],
        'ld-linux-aarch64.so.1': ['GLIBC_2.9'],
      });
    });

    test('a version-needed section running past its end is refused', () {
      final cut = Uint8List.fromList(crafted);
      final data = ByteData.sublistView(cut);
      // sh_size of section 2, the version-needed section: one entry and
      // half of its first version.
      final size = data.getUint64(0x28, Endian.little).toInt() + 2 * 64 + 32;
      data.setUint64(size, 24, Endian.little);

      check(() => readElf(cut)).throws<FormatException>();
    });

    test('is a GLIBC_ version, read as numbers', () {
      check(glibcVersion('GLIBC_2.17')).isNotNull().deepEquals([2, 17]);
      check(glibcVersion('GLIBC_2.3.4')).isNotNull().deepEquals([2, 3, 4]);
      check(glibcVersion('GLIBC_PRIVATE')).isNull();
      check(glibcVersion('GCC_3.0')).isNull();
    });

    test('is the highest version any library names, compared number by '
        'number', () {
      ElfImage needing(List<String> versions) =>
          readElf(_craftedElf({'libc.so.6': versions}));

      check(
          glibcRequirement({
            'libtree-sitter.so': readElf(crafted),
            'liba.so': needing(['GLIBC_2.9', 'GLIBC_2.3.4']),
          }),
        ).isNotNull()
        ..has((it) => it.version, 'version').equals('2.34')
        ..has((it) => it.library, 'library').equals('libtree-sitter.so');
      check(
          glibcRequirement({
            'liba.so': needing(['GLIBC_2.9']),
            'libb.so': needing(['GLIBC_2.17', 'GLIBC_2.3.4']),
          }),
        ).isNotNull()
        ..has((it) => it.version, 'version').equals('2.17')
        ..has((it) => it.library, 'library').equals('libb.so');
      check(
        glibcRequirement({
          'liba.so': needing(['GLIBC_2.34']),
          'libb.so': needing(['GLIBC_2.39']),
          'libc.so': needing(['GLIBC_2.17']),
        }),
      ).isNotNull().has((it) => it.version, 'version').equals('2.39');
      check(
        glibcRequirement({
          'liba.so': needing(['GLIBC_PRIVATE']),
        }),
      ).isNull();
    });

    test('recorded as another version is refused', () {
      final scratch = Directory.systemTemp.createTempSync('elf_test');
      addTearDown(() => scratch.deleteSync(recursive: true));
      final paths = [
        for (final (name, version) in [
          ('liba.so', 'GLIBC_2.9'),
          ('libb.so', 'GLIBC_2.17'),
        ])
          (File(p.join(scratch.path, name))..writeAsBytesSync(
                _craftedElf({
                  'libc.so.6': [version],
                }),
              ))
              .path,
      ];

      check(glibcRequirementProblems('2.17', paths)).isEmpty();
      check(glibcRequirementProblems('2.9', paths)).deepEquals([
        'build_info.json records the glibc requirement 2.9; ${paths[1]} '
            'needs glibc 2.17',
      ]);
      check(glibcRequirementProblems(null, paths)).deepEquals([
        'build_info.json records the glibc requirement null; ${paths[1]} '
            'needs glibc 2.17',
      ]);
    });
  });

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
    check(compiler.hostLibc).isNotNull().startsWith('glibc ');
    check(compiler.hostLibcPath).isNotNull().endsWith('libc.so.6');
    check(p.isAbsolute(compiler.hostLibcPath!)).isTrue();
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
    check(image.versionsNeeded).deepEquals({
      'libc.so.6': ['GLIBC_2.17'],
    });
    check(readGlibcRequirement([path])).isNotNull()
      ..has((it) => it.version, 'version').equals('2.17')
      ..has((it) => it.library, 'library').equals(path);
  });

  test('a shared object recorded as needing another glibc than its '
      'symbols name is refused', () async {
    final path = await library('x');

    check(glibcRequirementProblems('2.17', [path])).isEmpty();
    check(glibcRequirementProblems('2.39', [path])).deepEquals([
      'build_info.json records the glibc requirement 2.39; $path needs '
          'glibc 2.17',
    ]);
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
