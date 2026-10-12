/// Checks each built Windows library's PE headers, imports and exports, as
/// `macho.dart` checks a macOS library's load commands.
///
/// The headers are read in Dart rather than through a tool's printout, so
/// the check depends on no tool's version or output format.
library;

import 'dart:io';
import 'dart:typed_data';

import 'build_platform.dart';

/// What one Windows library must look like.
final class DllExpectation {
  const DllExpectation({
    required this.path,
    required this.name,
    required this.exportedSymbols,
  });

  /// The library's path.
  final String path;

  /// The name its export table must carry, its own file name, for example
  /// `tree-sitter.dll`: what the loader knows it by, as an install name is
  /// on macOS.
  final String name;

  /// Symbols it must export, as C spells them (no leading underscore).
  final List<String> exportedSymbols;
}

/// What [readPe] reads of a PE image.
typedef PeImage = ({
  int machine,
  bool isDll,
  String? exportName,
  List<String> exports,
  List<String> imports,
  List<String> delayImports,
});

/// The `IMAGE_FILE_MACHINE_*` value of each Windows platform.
int peMachine(BuildPlatform platform) => switch (platform) {
  BuildPlatform.windowsArm64 => 0xaa64,
  BuildPlatform.windowsX64 => 0x8664,
  BuildPlatform.macosArm64 => throw StateError('macOS builds no PE image'),
};

/// Whether a library may import from the DLL [name]: `KERNEL32.dll`, and
/// the `api-ms-win-crt-*` sets through which the Universal CRT, part of
/// Windows 10 and later, is reached. Anything else, the Visual C++
/// runtime's `VCRUNTIME140.dll` among them, would have to ship beside the
/// library.
bool isSystemImport(String name) =>
    name.toLowerCase() == 'kernel32.dll' ||
    RegExp(r'^api-ms-win-crt-[a-z0-9-]+\.dll$').hasMatch(name.toLowerCase());

/// Every way the library at [expectation] differs from what [platform]
/// requires; empty when it is right.
///
/// The library must be a DLL for [platform]'s machine whose export table
/// carries [DllExpectation.name], which imports only what
/// [isSystemImport] allows and delay-loads nothing, and which exports
/// every expected symbol.
List<String> dllProblems(DllExpectation expectation, BuildPlatform platform) {
  final path = expectation.path;
  final PeImage image;
  try {
    image = readPe(File(path).readAsBytesSync());
  } on FormatException catch (error) {
    return ['$path: ${error.message}'];
  }
  final machine = peMachine(platform);
  return [
    if (image.machine != machine)
      '$path: machine 0x${image.machine.toRadixString(16)}, not '
          '0x${machine.toRadixString(16)}',
    if (!image.isDll) '$path: not a DLL',
    if (image.exportName != expectation.name)
      '$path: export name ${image.exportName}',
    for (final name in image.imports)
      if (!isSystemImport(name)) '$path: depends on $name',
    for (final name in image.delayImports) '$path: delay-loads $name',
    for (final symbol in expectation.exportedSymbols)
      if (!image.exports.contains(symbol)) '$path: no $symbol',
  ];
}

/// Reads the machine, the DLL flag, the export table and the import
/// tables of the PE32+ image [bytes].
///
/// Throws a [FormatException] for anything that is not a PE32+ image.
PeImage readPe(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  int u16(int offset) => data.getUint16(offset, Endian.little);
  int u32(int offset) => data.getUint32(offset, Endian.little);
  if (bytes.length < 0x40 || u16(0) != 0x5a4d) {
    throw const FormatException('not a PE image: no MZ header');
  }
  final pe = u32(0x3c);
  if (pe + 24 > bytes.length || u32(pe) != 0x00004550) {
    throw const FormatException('not a PE image: no PE signature');
  }
  final coff = pe + 4;
  final machine = u16(coff);
  final sectionCount = u16(coff + 2);
  final optionalSize = u16(coff + 16);
  final characteristics = u16(coff + 18);
  final optional = coff + 20;
  if (u16(optional) != 0x20b) {
    throw const FormatException('not a PE32+ image');
  }
  final directoryCount = u32(optional + 108);
  ({int rva, int size}) directory(int index) => index < directoryCount
      ? (
          rva: u32(optional + 112 + index * 8),
          size: u32(optional + 116 + index * 8),
        )
      : (rva: 0, size: 0);
  final sections = optional + optionalSize;
  int offsetOf(int rva) {
    for (var index = 0; index < sectionCount; index++) {
      final header = sections + index * 40;
      final virtualAddress = u32(header + 12);
      final virtualSize = u32(header + 8);
      final rawSize = u32(header + 16);
      final extent = virtualSize > rawSize ? virtualSize : rawSize;
      if (rva >= virtualAddress && rva < virtualAddress + extent) {
        return rva - virtualAddress + u32(header + 20);
      }
    }
    throw FormatException('RVA 0x${rva.toRadixString(16)} is in no section');
  }

  String cString(int rva) {
    final start = offsetOf(rva);
    var end = start;
    while (bytes[end] != 0) {
      end++;
    }
    return String.fromCharCodes(bytes, start, end);
  }

  String? exportName;
  final exports = <String>[];
  final exportDirectory = directory(0);
  if (exportDirectory.rva != 0) {
    final table = offsetOf(exportDirectory.rva);
    exportName = cString(u32(table + 12));
    final names = offsetOf(u32(table + 32));
    for (var index = 0; index < u32(table + 24); index++) {
      exports.add(cString(u32(names + index * 4)));
    }
  }
  List<String> importNames(int index, int descriptorSize, int nameOffset) {
    final table = directory(index);
    if (table.rva == 0) return const [];
    final names = <String>[];
    for (var at = offsetOf(table.rva); ; at += descriptorSize) {
      if (bytes.sublist(at, at + descriptorSize).every((byte) => byte == 0)) {
        break;
      }
      names.add(cString(u32(at + nameOffset)));
    }
    return names;
  }

  return (
    machine: machine,
    isDll: characteristics & 0x2000 != 0,
    exportName: exportName,
    exports: exports,
    imports: importNames(1, 20, 12),
    delayImports: importNames(13, 32, 4),
  );
}
