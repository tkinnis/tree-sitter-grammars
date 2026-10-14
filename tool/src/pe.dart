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
  BuildPlatform.macosArm64 || BuildPlatform.linuxArm64 => throw StateError(
    '${platform.osName} builds no PE image',
  ),
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
/// Throws a [FormatException] for anything that is not a PE32+ image, and
/// for one whose headers or tables the file does not hold: every read is
/// bounded first, and one that would fall outside the file, or outside the
/// raw data of the section an RVA lies in, names what is cut short (the
/// PE signature `e_lfanew` points at, the COFF header, the optional header
/// or its data directories, the section table, the export directory, its
/// name pointers or a name, or an import or delay-load descriptor or its
/// DLL's name).
PeImage readPe(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  void require(bool holds, String what) {
    if (!holds) throw FormatException('malformed PE image: $what');
  }

  // Whether [length] bytes from [offset] lie within the file.
  bool within(int offset, int length) =>
      offset >= 0 && length >= 0 && length <= bytes.length - offset;
  int u16(int offset, String what) {
    require(within(offset, 2), '$what cut short');
    return data.getUint16(offset, Endian.little);
  }

  int u32(int offset, String what) {
    require(within(offset, 4), '$what cut short');
    return data.getUint32(offset, Endian.little);
  }

  String hex(int value) => '0x${value.toRadixString(16)}';

  if (bytes.length < 0x40 || u16(0, 'DOS header') != 0x5a4d) {
    throw const FormatException('not a PE image: no MZ header');
  }
  final pe = u32(0x3c, 'DOS header');
  require(within(pe, 4), 'PE signature at e_lfanew ${hex(pe)} cut short');
  if (u32(pe, 'PE signature') != 0x00004550) {
    throw const FormatException('not a PE image: no PE signature');
  }
  final coff = pe + 4;
  final machine = u16(coff, 'COFF header');
  final sectionCount = u16(coff + 2, 'COFF header');
  final optionalSize = u16(coff + 16, 'COFF header');
  final characteristics = u16(coff + 18, 'COFF header');
  final optional = coff + 20;
  if (u16(optional, 'optional header') != 0x20b) {
    throw const FormatException('not a PE32+ image');
  }
  // The fields of a PE32+ optional header before its data directories.
  const optionalFixed = 112;
  require(
    optionalSize >= optionalFixed,
    'optional header of $optionalSize bytes, short of the $optionalFixed '
    'of PE32+',
  );
  require(within(optional, optionalSize), 'optional header cut short');
  final directoryCount = u32(optional + 108, 'optional header');
  require(
    directoryCount <= (optionalSize - optionalFixed) ~/ 8,
    '$directoryCount data directories cut short by an optional header of '
    '$optionalSize bytes',
  );
  ({int rva, int size}) directory(int index) => index < directoryCount
      ? (
          rva: u32(optional + 112 + index * 8, 'data directory $index'),
          size: u32(optional + 116 + index * 8, 'data directory $index'),
        )
      : (rva: 0, size: 0);
  final sections = optional + optionalSize;
  require(within(sections, sectionCount * 40), 'section table cut short');

  // The file offset of [rva] and the end of the file's bytes of the
  // section it lies in: its raw data, as far as the file holds it.
  ({int offset, int end}) locate(int rva, String what) {
    for (var index = 0; index < sectionCount; index++) {
      final header = sections + index * 40;
      final virtualSize = u32(header + 8, 'section header $index');
      final virtualAddress = u32(header + 12, 'section header $index');
      final rawSize = u32(header + 16, 'section header $index');
      final rawOffset = u32(header + 20, 'section header $index');
      final extent = virtualSize > rawSize ? virtualSize : rawSize;
      if (rva >= virtualAddress && rva < virtualAddress + extent) {
        final rawEnd = rawOffset + rawSize;
        return (
          offset: rawOffset + rva - virtualAddress,
          end: rawEnd < bytes.length ? rawEnd : bytes.length,
        );
      }
    }
    throw FormatException(
      'malformed PE image: $what at RVA ${hex(rva)} is in no section',
    );
  }

  // The file offset of the [length] bytes at [rva], which must lie in the
  // file's bytes of one section.
  int at(int rva, int length, String what) {
    final (:offset, :end) = locate(rva, what);
    require(length <= end - offset, '$what cut short');
    return offset;
  }

  String cString(int rva, String what) {
    final (:offset, :end) = locate(rva, what);
    var close = offset;
    while (close < end && bytes[close] != 0) {
      close++;
    }
    require(close < end, '$what cut short');
    return String.fromCharCodes(bytes, offset, close);
  }

  String? exportName;
  final exports = <String>[];
  final exportDirectory = directory(0);
  if (exportDirectory.rva != 0) {
    const what = 'export directory';
    final table = at(exportDirectory.rva, 40, what);
    exportName = cString(u32(table + 12, what), 'export name');
    final count = u32(table + 24, what);
    if (count > 0) {
      const pointers = 'export name pointers';
      final names = at(u32(table + 32, what), count * 4, pointers);
      for (var index = 0; index < count; index++) {
        exports.add(
          cString(u32(names + index * 4, pointers), 'exported name $index'),
        );
      }
    }
  }
  List<String> importNames(
    int index,
    int descriptorSize,
    int nameOffset,
    String kind,
  ) {
    final table = directory(index);
    if (table.rva == 0) return const [];
    final names = <String>[];
    for (var entry = 0; ; entry++) {
      final what = '$kind descriptor $entry';
      final descriptor = at(
        table.rva + entry * descriptorSize,
        descriptorSize,
        what,
      );
      if (bytes
          .getRange(descriptor, descriptor + descriptorSize)
          .every((byte) => byte == 0)) {
        break;
      }
      names.add(
        cString(u32(descriptor + nameOffset, what), '$kind DLL name $entry'),
      );
    }
    return names;
  }

  return (
    machine: machine,
    isDll: characteristics & 0x2000 != 0,
    exportName: exportName,
    exports: exports,
    imports: importNames(1, 20, 12, 'import'),
    delayImports: importNames(13, 32, 4, 'delay-load import'),
  );
}
