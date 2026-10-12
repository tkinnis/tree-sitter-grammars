/// The platforms a build targets, and what each names its libraries and
/// its release archive.
///
/// A build targets the platform it runs on: `tool/check_release.dart`
/// loads every library it ships with `dart:ffi`, which only a process of
/// the same platform can do. So macOS on arm64 builds `macos-arm64`, Linux
/// on arm64 builds `linux-arm64`, and Windows builds `windows-arm64` or
/// `windows-x64` by the architecture of the Dart that runs it; an x64 Dart
/// on an arm64 machine builds x64.
///
/// A platform is a row of [BuildPlatform], and what its operating system
/// names a library a row of [_operatingSystems]; a new architecture of an
/// operating system the build knows adds a row to the first, and the
/// switches over [BuildPlatform] that name its target and machine.
library;

import 'dart:ffi';

/// Thrown when a build is asked for a platform it does not target.
final class BuildPlatformException implements Exception {
  const BuildPlatformException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// What one operating system calls itself and its libraries: the name a
/// message gives it, and the prefix and extension of a library's file
/// name, as `package:code_assets`'s `OS.dylibFileName` spells them.
typedef _OperatingSystem = ({
  String name,
  String libraryPrefix,
  String libraryExtension,
});

/// Every operating system a build targets, by [BuildPlatform.os].
const _operatingSystems = <String, _OperatingSystem>{
  'macos': (name: 'macOS', libraryPrefix: 'lib', libraryExtension: '.dylib'),
  'linux': (name: 'Linux', libraryPrefix: 'lib', libraryExtension: '.so'),
  'windows': (name: 'Windows', libraryPrefix: '', libraryExtension: '.dll'),
};

/// One platform a build targets.
enum BuildPlatform {
  macosArm64(os: 'macos', arch: 'arm64'),
  linuxArm64(os: 'linux', arch: 'arm64'),
  windowsArm64(os: 'windows', arch: 'arm64'),
  windowsX64(os: 'windows', arch: 'x64');

  const BuildPlatform({required this.os, required this.arch});

  /// `macos`, `linux` or `windows`, as `Platform.operatingSystem` spells
  /// it.
  final String os;

  /// The architecture as the platform's id spells it: `arm64` or `x64`.
  final String arch;

  /// The platform as `build_info.json` records it and the archive's name
  /// carries it, for example `windows-arm64`.
  String get id => '$os-$arch';

  _OperatingSystem get _system => _operatingSystems[os]!;

  /// The operating system's name as a message gives it: `macOS`, `Linux`
  /// or `Windows`.
  String get osName => _system.name;

  bool get isMacos => os == 'macos';

  bool get isLinux => os == 'linux';

  bool get isWindows => os == 'windows';

  /// The platform this process runs on.
  ///
  /// Throws a [BuildPlatformException] on any other, since a build cannot
  /// check libraries it cannot load.
  static BuildPlatform get host => switch (Abi.current()) {
    Abi.macosArm64 => macosArm64,
    Abi.linuxArm64 => linuxArm64,
    Abi.windowsArm64 => windowsArm64,
    Abi.windowsX64 => windowsX64,
    final abi => throw BuildPlatformException(
      'a build runs on ${[for (final platform in values) platform.id].join(', ')}, '
      'not $abi',
    ),
  };

  /// The platform [id] names, or null when no platform has that id.
  static BuildPlatform? parse(Object? id) =>
      values.where((platform) => platform.id == id).firstOrNull;

  /// The runtime's file name: `libtree-sitter.dylib` on macOS,
  /// `libtree-sitter.so` on Linux and `tree-sitter.dll` on Windows, the
  /// names each platform's own build of tree-sitter gives it (unversioned
  /// on Linux, as the archive ships no symbolic links).
  String get runtimeFileName => libraryFileName('tree-sitter');

  /// The file name of the library named [name] (a grammar's language id,
  /// or `tree-sitter`): `lib<name>.dylib` on macOS, `lib<name>.so` on
  /// Linux, `<name>.dll` on Windows, as `package:code_assets`'s
  /// `OS.dylibFileName` spells it.
  String libraryFileName(String name) =>
      '${_system.libraryPrefix}$name${_system.libraryExtension}';

  /// Whether [path] names a library of this platform.
  bool isLibrary(String path) => path.endsWith(_system.libraryExtension);

  /// Whether [path] names a library of any platform a build targets.
  static bool isAnyLibrary(String path) =>
      values.any((platform) => platform.isLibrary(path));

  /// The release asset a build for this platform packs.
  String get releaseArchiveName => 'grammars-$id.tar.gz';

  /// The archive a `--dry-run` build packs: the bytes a tagged build of the
  /// same commit packs, under a name no release asset has.
  String get dryRunArchiveName => 'grammars-$id.dry-run.tar.gz';

  /// The clang target triple of a Windows platform.
  String get windowsTarget => switch (this) {
    windowsArm64 => 'aarch64-pc-windows-msvc',
    windowsX64 => 'x86_64-pc-windows-msvc',
    macosArm64 ||
    linuxArm64 => throw StateError('$id is not a Windows platform'),
  };

  /// The directory name of this platform's architecture under the MSVC
  /// tools' and the Windows SDK's `lib`.
  String get windowsLibArch => switch (this) {
    windowsArm64 => 'arm64',
    windowsX64 => 'x64',
    macosArm64 ||
    linuxArm64 => throw StateError('$id is not a Windows platform'),
  };

  /// The clang target triple of a Linux platform: the GNU triple Debian
  /// and Ubuntu name their multiarch directories and GCC installation by,
  /// against whose C library the libraries are linked.
  String get linuxTarget => switch (this) {
    linuxArm64 => 'aarch64-linux-gnu',
    macosArm64 ||
    windowsArm64 ||
    windowsX64 => throw StateError('$id is not a Linux platform'),
  };
}
