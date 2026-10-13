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

/// One section of a crafted image: its `sh_type`, its contents, the
/// section its `sh_link` names and its `sh_entsize`. A section of
/// [_noBits] holds no bytes of the file; [size] gives its `sh_size`.
final class _Section {
  const _Section(
    this.type, {
    this.bytes = const [],
    this.link = 0,
    this.entrySize = 0,
    this.size,
  });

  final int type;
  final List<int> bytes;
  final int link;
  final int entrySize;
  final int? size;
}

const _stringTable = 3; // SHT_STRTAB
const _dynamic = 6; // SHT_DYNAMIC
const _noBits = 8; // SHT_NOBITS
const _dynamicSymbols = 11; // SHT_DYNSYM
const _versionsNeeded = 0x6ffffffe; // SHT_GNU_verneed

/// The strings of a crafted string table, the empty string first.
final class _Strings {
  final _bytes = BytesBuilder()..addByte(0);

  /// Adds [text] and returns its offset in the table.
  int add(String text) {
    final at = _bytes.length;
    _bytes
      ..add(text.codeUnits)
      ..addByte(0);
    return at;
  }

  _Section get section => _Section(_stringTable, bytes: _bytes.toBytes());
}

/// A crafted 64-bit little-endian shared object for arm64 holding
/// [sections] after the null section 0, each at an 8-byte boundary, as a
/// linker lays them out, and its section headers last.
Uint8List _image(List<_Section> sections) {
  int aligned(int offset) => (offset + 7) & ~7;
  final offsets = <int>[];
  var at = 64;
  for (final section in sections) {
    offsets.add(at);
    if (section.type != _noBits) at = aligned(at + section.bytes.length);
  }
  final sectionsAt = at;
  final count = sections.length + 1;
  final bytes = Uint8List(sectionsAt + count * 64)
    ..setAll(0, [0x7f, 0x45, 0x4c, 0x46, 2, 1, 1]);
  final data = ByteData.sublistView(bytes)
    ..setUint16(16, elfSharedObject, Endian.little)
    ..setUint16(18, 183 /* EM_AARCH64 */, Endian.little)
    ..setUint64(0x28, sectionsAt, Endian.little)
    ..setUint16(0x34, 64, Endian.little)
    ..setUint16(0x3a, 64, Endian.little)
    ..setUint16(0x3c, count, Endian.little);
  for (final (index, section) in sections.indexed) {
    if (section.type != _noBits) bytes.setAll(offsets[index], section.bytes);
    final header = sectionsAt + 64 * (index + 1);
    data
      ..setUint32(header + 4, section.type, Endian.little)
      ..setUint64(header + 24, offsets[index], Endian.little)
      ..setUint64(
        header + 32,
        section.size ?? section.bytes.length,
        Endian.little,
      )
      ..setUint32(header + 40, section.link, Endian.little)
      ..setUint64(header + 56, section.entrySize, Endian.little);
  }
  return bytes;
}

/// The offset of the section header of section [index] in [image].
int _sectionHeader(Uint8List image, int index) =>
    ByteData.sublistView(image).getUint64(0x28, Endian.little).toInt() +
    64 * index;

/// [image] with the 64-bit field at [offset] set to [value], which may be
/// any 64-bit pattern, those Dart reads back as negative among them.
Uint8List _with(Uint8List image, int offset, int value) {
  final copy = Uint8List.fromList(image);
  ByteData.sublistView(copy).setUint64(offset, value, Endian.little);
  return copy;
}

/// The `Elf64_Dyn` entries of [entries], `(d_tag, d_val)`, and `DT_NULL`.
_Section _dynamicSection(List<(int, int)> entries, {int link = 1}) {
  final data = ByteData(16 * (entries.length + 1));
  for (final (index, (tag, value)) in entries.indexed) {
    data
      ..setUint64(16 * index, tag, Endian.little)
      ..setUint64(16 * index + 8, value, Endian.little);
  }
  return _Section(
    _dynamic,
    bytes: data.buffer.asUint8List(),
    link: link,
    entrySize: 16,
  );
}

/// One `Elf64_Sym`: the offset of its name, its binding (`STB_*`), its
/// visibility (`STV_*`) and the section that defines it, 0 for none.
typedef _Symbol = ({int name, int binding, int visibility, int section});

/// The `.dynsym` of [symbols] after the null symbol, its names in section
/// [link].
_Section _symbolSection(List<_Symbol> symbols, {int link = 1}) {
  final data = ByteData(24 * (symbols.length + 1));
  for (final (index, symbol) in symbols.indexed) {
    final at = 24 * (index + 1);
    data
      ..setUint32(at, symbol.name, Endian.little)
      ..setUint8(at + 4, symbol.binding << 4 | 2 /* STT_FUNC */)
      ..setUint8(at + 5, symbol.visibility)
      ..setUint16(at + 6, symbol.section, Endian.little);
  }
  return _Section(
    _dynamicSymbols,
    bytes: data.buffer.asUint8List(),
    link: link,
    entrySize: 24,
  );
}

/// A crafted shared object for arm64 holding only a string table and a
/// version-needed section that lists, by file, the versions [needs]
/// names, laid out as a linker lays them out.
Uint8List _craftedElf(Map<String, List<String>> needs) {
  final strings = _Strings();
  final need = BytesBuilder();
  final files = needs.entries.toList();
  for (final (index, MapEntry(key: file, value: versions)) in files.indexed) {
    final entry = ByteData(16 + 16 * versions.length)
      ..setUint16(0, 1, Endian.little) // vn_version
      ..setUint16(2, versions.length, Endian.little) // vn_cnt
      ..setUint32(4, strings.add(file), Endian.little) // vn_file
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
        ..setUint32(aux + 8, strings.add(version), Endian.little) // vna_name
        ..setUint32(
          aux + 12,
          at == versions.length - 1 ? 0 : 16,
          Endian.little,
        ); // vna_next
    }
    need.add(entry.buffer.asUint8List());
  }
  return _image([
    strings.section,
    _Section(_versionsNeeded, bytes: need.toBytes(), link: 1),
  ]);
}

/// A crafted `libx.so` whose dynamic section names its soname and
/// `libc.so.6`, then [dynamic], and whose `.dynsym` holds `tree_sitter_x`,
/// bound global, defined in section 1; [after] follow its four sections.
Uint8List _library({
  List<(int, int)> dynamic = const [],
  List<_Section> after = const [],
}) {
  final strings = _Strings();
  final soname = strings.add('libx.so');
  final libc = strings.add('libc.so.6');
  final symbol = strings.add('tree_sitter_x');
  return _image([
    strings.section,
    _dynamicSection([
      (14 /* DT_SONAME */, soname),
      (1 /* DT_NEEDED */, libc),
      ...dynamic,
    ]),
    _symbolSection([(name: symbol, binding: 1, visibility: 0, section: 1)]),
    ...after,
  ]);
}

/// [elfProblems] of [image], written to a file of its own, against the
/// expectation [_library] meets.
List<String> _problemsOf(Uint8List image) {
  final scratch = Directory.systemTemp.createTempSync('elf_test');
  addTearDown(() => scratch.deleteSync(recursive: true));
  final path = p.join(scratch.path, 'libx.so');
  File(path).writeAsBytesSync(image);
  return elfProblems(
    ElfExpectation(
      path: path,
      soname: 'libx.so',
      exportedSymbols: const ['tree_sitter_x'],
    ),
    BuildPlatform.linuxArm64,
  ).map((problem) => problem.replaceFirst(path, 'libx.so')).toList();
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

    test('counts GLIBC_ABI_DT_RELR as the glibc 2.36 that defines it', () {
      check(glibcVersion('GLIBC_ABI_DT_RELR')).isNotNull().deepEquals([2, 36]);
      check(
        glibcRequirement({
          'libtree-sitter.so': readElf(
            _craftedElf({
              'libc.so.6': ['GLIBC_2.17', 'GLIBC_ABI_DT_RELR'],
            }),
          ),
        }),
      ).isNotNull().has((it) => it.version, 'version').equals('2.36');
    });

    test('is unknown for a GLIBC_ name of no known release', () {
      check(isUnknownGlibcVersion('GLIBC_ABI_SOMETHING_NEW')).isTrue();
      check(isUnknownGlibcVersion('GLIBC_ABI_DT_RELR')).isFalse();
      check(isUnknownGlibcVersion('GLIBC_2.17')).isFalse();
      check(isUnknownGlibcVersion('GLIBC_PRIVATE')).isFalse();
      check(isUnknownGlibcVersion('GCC_3.0')).isFalse();
    });

    test('of no known release is refused', () {
      final scratch = Directory.systemTemp.createTempSync('elf_test');
      addTearDown(() => scratch.deleteSync(recursive: true));
      final path =
          (File(p.join(scratch.path, 'liba.so'))..writeAsBytesSync(
                _craftedElf({
                  'libc.so.6': ['GLIBC_2.17', 'GLIBC_ABI_SOMETHING_NEW'],
                }),
              ))
              .path;

      check(
        elfProblems(
          ElfExpectation(path: path, soname: 'liba.so', exportedSymbols: []),
          BuildPlatform.linuxArm64,
        ),
      ).contains(
        '$path: needs GLIBC_ABI_SOMETHING_NEW, a glibc version of no known '
        'release',
      );
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

  group('a crafted image', () {
    test('as a linker lays it out is read and passes', () {
      final image = readElf(_library());

      check(image.soname).equals('libx.so');
      check(image.needed).deepEquals(['libc.so.6']);
      check(image.exports).deepEquals(['tree_sitter_x']);
      check(image.textRelocations).isFalse();
      check(_problemsOf(_library())).isEmpty();
    });

    test('cut short anywhere is refused as malformed, not read past its '
        'end', () {
      final whole = _library();
      for (final length in [
        0,
        10,
        63,
        64,
        100,
        whole.length - 64,
        whole.length - 1,
      ]) {
        final cut = Uint8List.sublistView(whole, 0, length);

        check(because: 'cut to $length bytes', () => readElf(cut))
            .throws<FormatException>()
            .has((e) => e.message, 'message')
            .equals(
              length < 64
                  ? 'not an ELF image: no ELF header'
                  : 'malformed ELF image: section headers past the end of '
                        'the file',
            );
        check(
          because: 'cut to $length bytes',
          _problemsOf(cut),
        ).length.equals(1);
      }
    });

    test('a huge offset, size or string index is refused as malformed, '
        'not a crash', () {
      final whole = _library();
      final dynamicHeader = _sectionHeader(whole, 2);
      final dynamicAt = ByteData.sublistView(
        whole,
      ).getUint64(dynamicHeader + 24, Endian.little).toInt();
      for (final (what, image, problem) in [
        // 0xfff...f0 reads in Dart as -16.
        (
          'a section offset past 2^63',
          _with(whole, dynamicHeader + 24, -16),
          'section 2 past the end',
        ),
        (
          'a section size past 2^63',
          _with(whole, dynamicHeader + 32, -16),
          'section 2 past the end',
        ),
        (
          'an offset and size whose sum passes 2^63',
          _with(
            _with(whole, dynamicHeader + 24, 1 << 62),
            dynamicHeader + 32,
            1 << 62,
          ),
          'section 2 past the end',
        ),
        (
          'a section table past 2^63',
          _with(whole, 0x28, -64),
          'section headers past the end of the file',
        ),
        (
          'a soname past 2^63 in its table',
          _with(whole, dynamicAt + 8, -16),
          'string -16 outside its table',
        ),
      ]) {
        check(because: what, () => readElf(image))
            .throws<FormatException>()
            .has((e) => e.message, 'message')
            .equals('malformed ELF image: $problem');
        check(because: what, _problemsOf(image)).length.equals(1);
      }
    });

    test('a section that holds no bytes of the file, as .bss, may reach '
        'past its end', () {
      final image = _library(after: [const _Section(_noBits, size: 1 << 20)]);

      check(readElf(image).exports).deepEquals(['tree_sitter_x']);
      check(_problemsOf(image)).isEmpty();
    });

    test('a section linking to a section that does not exist is refused', () {
      final whole = _library();
      for (final index in [2, 3]) {
        final image = Uint8List.fromList(whole);
        ByteData.sublistView(
          image,
        ).setUint32(_sectionHeader(image, index) + 40, 9, Endian.little);

        check(() => readElf(image))
            .throws<FormatException>()
            .has((e) => e.message, 'message')
            .equals('malformed ELF image: section $index links section 9 of 4');
        check(_problemsOf(image)).length.equals(1);
      }
    });

    test('a string table that holds no bytes of the file is refused', () {
      final strings = _Strings();
      final soname = strings.add('libx.so');
      final image = _image([
        const _Section(_noBits, size: 64),
        _dynamicSection([(14 /* DT_SONAME */, soname)]),
      ]);

      check(() => readElf(image))
          .throws<FormatException>()
          .has((e) => e.message, 'message')
          .equals('malformed ELF image: section 1 is no string table');
    });

    test('has text relocations when its dynamic section holds DT_TEXTREL or '
        'DF_TEXTREL in DT_FLAGS', () {
      bool textRelocations(List<(int, int)> dynamic) =>
          readElf(_library(dynamic: dynamic)).textRelocations;

      check(textRelocations(const [])).isFalse();
      check(textRelocations(const [(22 /* DT_TEXTREL */, 0)])).isTrue();
      check(textRelocations(const [(30 /* DT_FLAGS */, 0x4)])).isTrue();
      check(
        textRelocations(const [(30 /* DT_FLAGS */, 0x8 /* BIND_NOW */)]),
      ).isFalse();
      check(
        _problemsOf(_library(dynamic: const [(30 /* DT_FLAGS */, 0x4)])),
      ).deepEquals(['libx.so: has text relocations']);
    });

    test('exports what is defined, bound global or weak, and of default or '
        'protected visibility', () {
      final strings = _Strings();
      _Symbol symbol(
        String name, {
        int binding = 1 /* GLOBAL */,
        int visibility = 0 /* DEFAULT */,
        int section = 1,
      }) => (
        name: strings.add(name),
        binding: binding,
        visibility: visibility,
        section: section,
      );
      final symbols = [
        symbol('global'),
        symbol('weak', binding: 2 /* WEAK */),
        symbol('protected', visibility: 3 /* PROTECTED */),
        symbol('weak_protected', binding: 2, visibility: 3),
        symbol('local', binding: 0 /* LOCAL */),
        symbol('hidden', visibility: 2 /* HIDDEN */),
        symbol('internal', visibility: 1 /* INTERNAL */),
        symbol('undefined', section: 0 /* SHN_UNDEF */),
        symbol('unique', binding: 10 /* GNU_UNIQUE */),
      ];

      check(
        readElf(_image([strings.section, _symbolSection(symbols)])).exports,
      ).deepEquals(['global', 'weak', 'protected', 'weak_protected']);
    });
  });

  if (!Platform.isLinux || !_hasClang) {
    test('links shared objects with the build\'s flags', () {
      markTestSkipped(
        Platform.isLinux
            ? 'no clang on PATH, which a build on Linux needs'
            : 'a shared object for Linux is linked only on Linux',
      );
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

  test('the compiler records the linker and the C library it links '
      'against', () async {
    check(compiler.hostLibc).isNotNull().startsWith('glibc ');
    check(compiler.hostLibcPath).isNotNull().endsWith('libc.so.6');
    check(p.isAbsolute(compiler.hostLibcPath!)).isTrue();
    check(compiler.linker).isNotNull().startsWith('GNU ld ');
    check(compiler.linkerPackage).isNotNull().contains(' ');
    check(p.isAbsolute(compiler.linkerPath!)).isTrue();
    check(compiler.hostLibcBanner).isNotNull().startsWith('GNU C Library (');
    check(compiler.sdkPath).isNull();
    // Read from the libc.so.6 clang links against, which on a host that
    // builds natively is the glibc this process runs on too.
    final running = await Process.run('getconf', ['GNU_LIBC_VERSION']);
    check(compiler.hostLibc).equals((running.stdout as String).trim());
    check(
      File(compiler.linkerPath!).resolveSymbolicLinksSync(),
    ).equals(compiler.linkerResolvedPath!);
  });

  test('a real link runs the linker the compiler records', () async {
    // -v prints each command as clang runs it, the link last, its program
    // in double quotes and each argument bare unless it needs them, as
    // none of this link's do.
    final source = p.join(scratch, 'tiny.c');
    File(source).writeAsStringSync('int tiny(void) { return 42; }\n');
    final result = await Process.run(
      compiler.path,
      [
        '-v',
        '-O3',
        '-fPIC',
        ...flags.grammarLink,
        ...grammarLinkFlags('tiny', platform: platform),
        source,
        '-o',
        p.join(scratch, 'libtiny.so'),
      ],
      environment: compilerEnvironment(Platform.environment),
      includeParentEnvironment: false,
    );
    check(because: '${result.stderr}', result.exitCode).equals(0);
    final line = '${result.stderr}'
        .split('\n')
        .lastWhere((line) => line.startsWith(' "'));
    final [linker, ...] = line.trim().split(' ');

    check(p.normalize(linker.replaceAll('"', ''))).equals(compiler.linkerPath!);
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
