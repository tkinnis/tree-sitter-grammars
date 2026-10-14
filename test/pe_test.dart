import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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

/// Whether a `clang.exe` is on `PATH`, which these tests link with as the
/// build does.
final _hasClang = (Platform.environment['PATH'] ?? '')
    .split(';')
    .any((directory) => File(p.join(directory, 'clang.exe')).existsSync());

/// Where a crafted image's headers lie: `e_lfanew` points at [_pe].
const _pe = 0x40;
const _coff = _pe + 4;
const _optional = _coff + 20;
const _optionalSize = 112 + 16 * 8;
const _sectionTable = _optional + _optionalSize;

/// The file offset and RVA of a crafted image's one section, `.rdata`.
const _sectionOffset = 0x200;
const _sectionRva = 0x1000;

/// The file offset of data directory [index]'s RVA in a crafted image.
int _directory(int index) => _optional + 112 + index * 8;

/// A crafted PE32+ DLL for arm64 whose export table names it [name] and
/// [exports], which imports [imports] and delay-loads [delayImports], all
/// in one section that ends the file. The section holds the export
/// directory, its name pointers, the strings, the delay-load descriptors
/// and, last, the import descriptors, so that cutting the file's end cuts
/// their terminator and nothing else.
Uint8List _craftedPe({
  String name = 'x.dll',
  List<String> exports = const ['tree_sitter_x'],
  List<String> imports = const ['KERNEL32.dll'],
  List<String> delayImports = const [],
}) {
  const pointers = 40;
  final strings = BytesBuilder();
  final stringsAt = pointers + 4 * exports.length;
  int string(String text) {
    final rva = _sectionRva + stringsAt + strings.length;
    strings
      ..add(ascii.encode(text))
      ..addByte(0);
    return rva;
  }

  final nameRva = string(name);
  final exportRvas = [for (final symbol in exports) string(symbol)];
  final importRvas = [for (final dll in imports) string(dll)];
  final delayRvas = [for (final dll in delayImports) string(dll)];
  final delayAt = stringsAt + strings.length;
  final importsAt = delayAt + 32 * (delayImports.length + 1);
  final length = importsAt + 20 * (imports.length + 1);

  final bytes = Uint8List(_sectionOffset + length);
  final data = ByteData.sublistView(bytes);
  void u16(int offset, int value) =>
      data.setUint16(offset, value, Endian.little);
  void u32(int offset, int value) =>
      data.setUint32(offset, value, Endian.little);

  u16(0, 0x5a4d); // MZ
  u32(0x3c, _pe);
  u32(_pe, 0x00004550); // PE\0\0
  u16(_coff, 0xaa64); // IMAGE_FILE_MACHINE_ARM64
  u16(_coff + 2, 1);
  u16(_coff + 16, _optionalSize);
  u16(_coff + 18, 0x2022); // DLL, large address aware, executable
  u16(_optional, 0x20b); // PE32+
  u32(_optional + 108, 16);
  u32(_directory(0), _sectionRva);
  u32(_directory(0) + 4, 40);
  u32(_directory(1), _sectionRva + importsAt);
  u32(_directory(1) + 4, 20 * (imports.length + 1));
  if (delayImports.isNotEmpty) {
    u32(_directory(13), _sectionRva + delayAt);
    u32(_directory(13) + 4, 32 * (delayImports.length + 1));
  }
  bytes.setAll(_sectionTable, ascii.encode('.rdata'));
  u32(_sectionTable + 8, length);
  u32(_sectionTable + 12, _sectionRva);
  u32(_sectionTable + 16, length);
  u32(_sectionTable + 20, _sectionOffset);

  const section = _sectionOffset;
  u32(section + 12, nameRva);
  u32(section + 24, exports.length);
  u32(section + 32, _sectionRva + pointers);
  for (final (index, rva) in exportRvas.indexed) {
    u32(section + pointers + index * 4, rva);
  }
  bytes.setAll(section + stringsAt, strings.takeBytes());
  for (final (index, rva) in delayRvas.indexed) {
    u32(section + delayAt + index * 32 + 4, rva);
  }
  for (final (index, rva) in importRvas.indexed) {
    u32(section + importsAt + index * 20 + 12, rva);
  }
  return bytes;
}

/// A copy of [image] with [change] made to it.
Uint8List _patched(Uint8List image, void Function(ByteData data) change) {
  final copy = Uint8List.fromList(image);
  change(ByteData.sublistView(copy));
  return copy;
}

/// The first [length] bytes of [image], as a file cut short holds them.
Uint8List _cut(Uint8List image, int length) =>
    Uint8List.fromList(image.sublist(0, length));

void main() {
  group('a crafted image', () {
    final crafted = _craftedPe(
      exports: ['tree_sitter_x', 'tree_sitter_y'],
      imports: ['KERNEL32.dll', 'api-ms-win-crt-heap-l1-1-0.dll'],
      delayImports: ['USER32.dll'],
    );

    /// Requires [readPe] of [image] to throw a [FormatException] whose
    /// message is `malformed PE image: ` and then [problem].
    void refused(Uint8List image, String problem) {
      check(() => readPe(image))
          .throws<FormatException>()
          .has((e) => e.message, 'message')
          .equals('malformed PE image: $problem');
    }

    test('is read whole', () {
      // The control of the cases below: the image each cuts or changes is
      // read without fault.
      final image = readPe(crafted);

      check(image.machine).equals(0xaa64);
      check(image.isDll).isTrue();
      check(image.exportName).equals('x.dll');
      check(image.exports).deepEquals(['tree_sitter_x', 'tree_sitter_y']);
      check(
        image.imports,
      ).deepEquals(['KERNEL32.dll', 'api-ms-win-crt-heap-l1-1-0.dll']);
      check(image.delayImports).deepEquals(['USER32.dll']);
    });

    test('whose e_lfanew points past the end is refused', () {
      // Reddened by dropping readPe's bound on e_lfanew, which leaves the
      // signature's read to say only that the signature is cut short.
      final pe = crafted.length - 2;
      final image = _patched(
        crafted,
        (data) => data.setUint32(0x3c, pe, Endian.little),
      );

      refused(
        image,
        'PE signature at e_lfanew 0x${pe.toRadixString(16)} cut short',
      );
    });

    test('cut inside its COFF header is refused', () {
      // Reddened by dropping the bound of readPe's u16, which then throws a
      // RangeError reading the COFF header's size of the optional header.
      refused(_cut(crafted, _coff + 10), 'COFF header cut short');
    });

    test('cut at the end of its COFF header is refused', () {
      // Reddened by dropping the bound of readPe's u16, which then throws a
      // RangeError reading the optional header's magic.
      refused(_cut(crafted, _optional), 'optional header cut short');
    });

    test('whose optional header is shorter than PE32+\'s is refused', () {
      // Reddened by dropping readPe's requirement that the optional header
      // hold the 112 bytes of PE32+ before its data directories, which
      // leaves the count of data directories to be refused for a negative
      // room.
      final image = _patched(
        crafted,
        (data) => data.setUint16(_coff + 16, 8, Endian.little),
      );

      refused(image, 'optional header of 8 bytes, short of the 112 of PE32+');
    });

    test('cut among its data directories is refused', () {
      // Reddened by dropping readPe's bound on the optional header, which
      // leaves the section table's bound to report the cut.
      refused(_cut(crafted, _directory(5)), 'optional header cut short');
    });

    test('counting more data directories than its optional header holds is '
        'refused', () {
      // Reddened by dropping readPe's bound on the count of data
      // directories, after which the image is read as though it held them.
      final image = _patched(
        crafted,
        (data) => data.setUint32(_optional + 108, 17, Endian.little),
      );

      refused(
        image,
        '17 data directories cut short by an optional header of 240 bytes',
      );
    });

    test('cut inside its section table is refused', () {
      // Reddened by dropping readPe's bound on the section table, which
      // leaves the read of the section's header to report the cut.
      refused(_cut(crafted, _sectionTable + 20), 'section table cut short');
    });

    test('whose export directory runs past its section\'s raw data is '
        'refused', () {
      // Reddened by dropping the bound of readPe's `at`, after which the
      // file's bytes past the section's raw data are read as the
      // directory.
      final image = _patched(
        crafted,
        (data) => data.setUint32(_sectionTable + 16, 20, Endian.little),
      );

      refused(image, 'export directory cut short');
    });

    test('naming more exports than it holds pointers to is refused', () {
      // Reddened by dropping the bound of readPe's `at`, after which the
      // strings and descriptors are read as name pointers.
      final image = _patched(
        crafted,
        (data) => data.setUint32(_sectionOffset + 24, 1000, Endian.little),
      );

      refused(image, 'export name pointers cut short');
    });

    test('whose export name runs past the end of the file is refused', () {
      // Reddened by dropping the end of the section's raw data from
      // cString's scan, which then throws a RangeError reading past the
      // file.
      final image = _patched(
        crafted,
        (data) => data.setUint32(
          _sectionOffset + 12,
          _sectionRva + crafted.length - 1 - _sectionOffset,
          Endian.little,
        ),
      );
      image[image.length - 1] = 0x78; // x, and no terminator after it

      refused(image, 'export name cut short');
    });

    test('cut inside the section that holds its names is refused', () {
      // Reddened by ending a section's raw data where its header says
      // rather than where the file does, after which cString scans past
      // the file and throws a RangeError. The export directory and its
      // name pointers come before the cut; the export name, the first
      // string, at 48 bytes into the section, straddles it.
      refused(_cut(crafted, _sectionOffset + 48 + 3), 'export name cut short');
    });

    test('whose import descriptors end without a terminator is refused', () {
      // Reddened by dropping the bound of readPe's `at`, after which the
      // terminator is read past the end of the file and throws a
      // RangeError.
      refused(
        _cut(crafted, crafted.length - 10),
        'import descriptor 2 cut short',
      );
    });

    test('whose delay-load descriptors run past the end is refused', () {
      // Reddened by dropping the bound of readPe's `at`, after which the
      // descriptor is read past the end of the file and throws a
      // RangeError.
      final image = _patched(
        crafted,
        (data) => data.setUint32(
          _directory(13),
          _sectionRva + crafted.length - _sectionOffset - 16,
          Endian.little,
        ),
      );

      refused(image, 'delay-load import descriptor 0 cut short');
    });
  });

  if (!Platform.isWindows || !_hasClang) {
    test('links DLLs with the build\'s flags', () {
      markTestSkipped(
        Platform.isWindows
            ? 'no clang.exe on PATH, which a build on Windows needs'
            : 'a DLL is linked only on Windows',
      );
    });
    return;
  }
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
