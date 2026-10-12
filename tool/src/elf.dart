/// Checks each built Linux library's ELF header, dynamic section and
/// exports, as `macho.dart` checks a macOS library's load commands and
/// `pe.dart` a Windows library's PE headers, and reads the glibc versions
/// it needs from its version-needed section.
///
/// The file is read in Dart rather than through a tool's printout, so the
/// check depends on no tool's version or output format.
library;

import 'dart:io';
import 'dart:typed_data';

import 'build_platform.dart';

/// What one Linux library must look like.
final class ElfExpectation {
  const ElfExpectation({
    required this.path,
    required this.soname,
    required this.exportedSymbols,
  });

  /// The library's path.
  final String path;

  /// The `DT_SONAME` it must carry, its own file name, for example
  /// `libtree-sitter.so`: what the loader knows it by, as an install name
  /// is on macOS.
  final String soname;

  /// Symbols it must export, as C spells them (no leading underscore).
  final List<String> exportedSymbols;
}

/// What [readElf] reads of an ELF image.
typedef ElfImage = ({
  int machine,
  int type,
  String? soname,
  List<String> needed,
  bool textRelocations,
  List<String> exports,
  Map<String, List<String>> versionsNeeded,
});

/// `ET_DYN`, the `e_type` of a shared object.
const elfSharedObject = 3;

/// The `EM_*` value of each Linux platform.
int elfMachine(BuildPlatform platform) => switch (platform) {
  BuildPlatform.linuxArm64 => 183 /* EM_AARCH64 */,
  BuildPlatform.macosArm64 ||
  BuildPlatform.windowsArm64 ||
  BuildPlatform.windowsX64 => throw StateError(
    '${platform.osName} builds no ELF image',
  ),
};

/// Whether a library may depend on the shared object [name]: the C
/// library alone, which every Linux system with glibc carries, as a macOS
/// library may depend on `libSystem` alone. Anything else would have to
/// ship beside the library.
bool isSystemLibrary(String name) => name == 'libc.so.6';

/// Every way the library at [expectation] differs from what [platform]
/// requires; empty when it is right.
///
/// The library must be a 64-bit little-endian shared object (`ET_DYN`)
/// for [platform]'s machine whose `DT_SONAME` is [ElfExpectation.soname],
/// which needs nothing but what [isSystemLibrary] allows, has no text
/// relocations (it was compiled position-independent), exports every
/// expected symbol, and needs no `GLIBC_` version of a release
/// [glibcVersion] cannot tell ([isUnknownGlibcVersion]).
List<String> elfProblems(ElfExpectation expectation, BuildPlatform platform) {
  final path = expectation.path;
  final ElfImage image;
  try {
    image = readElf(File(path).readAsBytesSync());
  } on FormatException catch (error) {
    return ['$path: ${error.message}'];
  }
  final machine = elfMachine(platform);
  return [
    if (image.machine != machine)
      '$path: machine ${image.machine}, not $machine',
    if (image.type != elfSharedObject)
      '$path: type ${image.type}, not a shared object',
    if (image.soname != expectation.soname) '$path: soname ${image.soname}',
    for (final name in image.needed)
      if (!isSystemLibrary(name)) '$path: depends on $name',
    if (image.textRelocations) '$path: has text relocations',
    for (final symbol in expectation.exportedSymbols)
      if (!image.exports.contains(symbol)) '$path: no $symbol',
    for (final names in image.versionsNeeded.values)
      for (final name in names)
        if (isUnknownGlibcVersion(name))
          '$path: needs $name, a glibc version of no known release',
  ];
}

/// Reads the machine, the type, the dynamic section, the exported
/// dynamic symbols and the version-needed section of the 64-bit
/// little-endian ELF image [bytes].
///
/// A symbol counts as exported when it is defined in a section, bound
/// global or weak, and of default or protected visibility: what the
/// dynamic linker resolves another object's reference to it with.
///
/// `versionsNeeded` holds, by the file each names, the symbol versions the
/// version-needed section (`.gnu.version_r`, `SHT_GNU_verneed`) lists, for
/// example `{'libc.so.6': ['GLIBC_2.17']}`: those the loader requires that
/// file to define before it loads the image.
///
/// Throws a [FormatException] for anything that is not such an image.
ElfImage readElf(Uint8List bytes) {
  if (bytes.length < 64 ||
      bytes[0] != 0x7f ||
      bytes[1] != 0x45 ||
      bytes[2] != 0x4c ||
      bytes[3] != 0x46) {
    throw const FormatException('not an ELF image: no ELF header');
  }
  if (bytes[4] != 2 || bytes[5] != 1) {
    throw const FormatException('not a 64-bit little-endian ELF image');
  }
  final data = ByteData.sublistView(bytes);
  int u16(int offset) => data.getUint16(offset, Endian.little);
  int u32(int offset) => data.getUint32(offset, Endian.little);
  int u64(int offset) => data.getUint64(offset, Endian.little);
  void require(bool holds, String what) {
    if (!holds) throw FormatException('malformed ELF image: $what');
  }

  final type = u16(16);
  final machine = u16(18);
  final sectionTable = u64(0x28);
  final sectionSize = u16(0x3a);
  final sectionCount = u16(0x3c);
  require(sectionSize == 64, 'section headers of $sectionSize bytes');
  require(
    sectionTable + sectionCount * sectionSize <= bytes.length,
    'section headers past the end of the file',
  );
  ({int type, int offset, int size, int link, int entrySize}) section(
    int index,
  ) {
    final header = sectionTable + index * sectionSize;
    final offset = u64(header + 24);
    final size = u64(header + 32);
    require(offset + size <= bytes.length, 'section $index past the end');
    return (
      type: u32(header + 4),
      offset: offset,
      size: size,
      link: u32(header + 40),
      entrySize: u64(header + 56),
    );
  }

  String string(int table, int at) {
    final strings = section(table);
    require(at < strings.size, 'string $at outside its table');
    final start = strings.offset + at;
    var end = start;
    while (end < strings.offset + strings.size && bytes[end] != 0) {
      end++;
    }
    return String.fromCharCodes(bytes, start, end);
  }

  const dynamicSection = 6;
  const dynamicSymbols = 11;
  const versionsNeededSection = 0x6ffffffe; // SHT_GNU_verneed
  String? soname;
  final needed = <String>[];
  var textRelocations = false;
  final exports = <String>[];
  final versionsNeeded = <String, List<String>>{};
  for (var index = 0; index < sectionCount; index++) {
    final current = section(index);
    if (current.type == dynamicSection) {
      entries:
      for (var at = 0; at + 16 <= current.size; at += 16) {
        final tag = u64(current.offset + at);
        final value = u64(current.offset + at + 8);
        switch (tag) {
          case 0: // DT_NULL
            break entries;
          case 1: // DT_NEEDED
            needed.add(string(current.link, value));
          case 14: // DT_SONAME
            soname = string(current.link, value);
          case 22: // DT_TEXTREL
            textRelocations = true;
          case 30: // DT_FLAGS
            if (value & 0x4 != 0) textRelocations = true; // DF_TEXTREL
        }
      }
    } else if (current.type == dynamicSymbols) {
      require(current.entrySize == 24, 'symbols of ${current.entrySize} bytes');
      for (var at = 0; at + 24 <= current.size; at += 24) {
        final symbol = current.offset + at;
        final binding = bytes[symbol + 4] >> 4;
        final visibility = bytes[symbol + 5] & 0x3;
        final sectionIndex = u16(symbol + 6);
        if (sectionIndex != 0 /* SHN_UNDEF */ &&
            (binding == 1 /* GLOBAL */ || binding == 2 /* WEAK */ ) &&
            (visibility == 0 /* DEFAULT */ ||
                visibility == 3 /* PROTECTED */ )) {
          exports.add(string(current.link, u32(symbol)));
        }
      }
    } else if (current.type == versionsNeededSection && current.size > 0) {
      // Elf64_Verneed entries, each followed through vn_aux by its
      // vn_cnt Elf64_Vernaux entries; vn_next and vna_next are byte
      // offsets from the entry, 0 after the last.
      final end = current.offset + current.size;
      var entry = current.offset;
      while (true) {
        require(entry + 16 <= end, 'version need past its section');
        require(u16(entry) == 1, 'version need of version ${u16(entry)}');
        final names = versionsNeeded.putIfAbsent(
          string(current.link, u32(entry + 4)),
          () => [],
        );
        var aux = entry + u32(entry + 8);
        for (var count = u16(entry + 2); count > 0; count--) {
          require(aux + 16 <= end, 'version need entry past its section');
          names.add(string(current.link, u32(aux + 8)));
          final next = u32(aux + 12);
          require(next != 0 || count == 1, 'version need entries end early');
          aux += next;
        }
        final next = u32(entry + 12);
        if (next == 0) break;
        entry += next;
      }
    }
  }
  return (
    machine: machine,
    type: type,
    soname: soname,
    needed: needed,
    textRelocations: textRelocations,
    exports: exports,
    versionsNeeded: versionsNeeded,
  );
}

final _glibcVersionName = RegExp(r'^GLIBC_(\d+(?:\.\d+)*)$');

/// The glibc release that first defines each `GLIBC_` symbol version
/// whose name holds no number: a feature of the image rather than of a
/// symbol, which the linker names in the version-needed section and the
/// loader refuses the image on an older glibc for. `GLIBC_ABI_DT_RELR`
/// is what a library linked with packed relative relocations
/// (`-z pack-relative-relocs`) needs.
const glibcAbiVersions = {
  'GLIBC_ABI_DT_RELR': [2, 36],
};

/// The numbers of the glibc release that defines the symbol version
/// [name], for example `[2, 17]` for `GLIBC_2.17` and `[2, 36]` for
/// `GLIBC_ABI_DT_RELR`, by [glibcAbiVersions]; null for any other name,
/// such as `GLIBC_PRIVATE`.
List<int>? glibcVersion(String name) =>
    glibcAbiVersions[name] ??
    _glibcVersionName
        .firstMatch(name)
        ?.group(1)!
        .split('.')
        .map(int.parse)
        .toList();

/// Whether [name] is a `GLIBC_` symbol version that [glibcVersion] knows
/// no release for and that is not `GLIBC_PRIVATE`: one whose glibc the
/// libraries' requirement cannot count, so it would promise too old a
/// glibc.
bool isUnknownGlibcVersion(String name) =>
    name.startsWith('GLIBC_') &&
    name != 'GLIBC_PRIVATE' &&
    glibcVersion(name) == null;

/// Orders the version numbers [a] and [b] number by number, a missing
/// number counting as 0, so that 2.9 comes before 2.17.
int compareVersions(List<int> a, List<int> b) {
  for (var i = 0; i < a.length || i < b.length; i++) {
    final order = (i < a.length ? a[i] : 0).compareTo(i < b.length ? b[i] : 0);
    if (order != 0) return order;
  }
  return 0;
}

/// The glibc a set of libraries needs: the highest [glibcVersion] of the
/// `GLIBC_` versions any of [images], by path, names in its version-needed
/// section, written as `build_info.json` records it (`2.17`), and the path
/// of the first image that names it; null when none names one.
({String version, String library})? glibcRequirement(
  Map<String, ElfImage> images,
) {
  List<int>? highest;
  String? library;
  for (final MapEntry(key: path, value: image) in images.entries) {
    for (final names in image.versionsNeeded.values) {
      for (final version in names.map(glibcVersion).nonNulls) {
        if (highest == null || compareVersions(version, highest) > 0) {
          highest = version;
          library = path;
        }
      }
    }
  }
  return highest == null
      ? null
      : (version: highest.join('.'), library: library!);
}

/// [glibcRequirement] of the libraries at [paths], read from disk.
///
/// Throws a [FormatException] for a file that is no ELF image.
({String version, String library})? readGlibcRequirement(List<String> paths) =>
    glibcRequirement({
      for (final path in paths) path: readElf(File(path).readAsBytesSync()),
    });

/// Every way [recorded], the `glibcRequirement` of `build_info.json`,
/// differs from the [glibcRequirement] of the libraries at [paths]; empty
/// when it is the version they need.
///
/// A file that is no ELF image is [elfProblems]' to report, and leaves
/// nothing to compare.
List<String> glibcRequirementProblems(Object? recorded, List<String> paths) {
  final ({String version, String library})? needed;
  try {
    needed = readGlibcRequirement(paths);
  } on FormatException {
    return const [];
  }
  return [
    if (needed == null)
      'no library names the glibc version it needs'
    else if (recorded != needed.version)
      'build_info.json records the glibc requirement $recorded; '
          '${needed.library} needs glibc ${needed.version}',
  ];
}
