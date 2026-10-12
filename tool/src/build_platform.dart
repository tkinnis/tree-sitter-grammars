/// The platforms a build targets, and what each names its libraries and
/// its release archive.
///
/// A build targets the platform it runs on: `tool/check_release.dart`
/// loads every library it ships with `dart:ffi`, which only a process of
/// the same platform can do. So macOS on arm64 builds `macos-arm64`, and
/// Windows builds `windows-arm64` or `windows-x64` by the architecture of
/// the Dart that runs it; an x64 Dart on an arm64 machine builds x64.
library;

import 'dart:ffi';

/// Thrown when a build is asked for a platform it does not target.
final class BuildPlatformException implements Exception {
  const BuildPlatformException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// One platform a build targets.
enum BuildPlatform {
  macosArm64(os: 'macos', arch: 'arm64'),
  windowsArm64(os: 'windows', arch: 'arm64'),
  windowsX64(os: 'windows', arch: 'x64');

  const BuildPlatform({required this.os, required this.arch});

  /// `macos` or `windows`.
  final String os;

  /// The architecture as the platform's id spells it: `arm64` or `x64`.
  final String arch;

  /// The platform as `build_info.json` records it and the archive's name
  /// carries it, for example `windows-arm64`.
  String get id => '$os-$arch';

  bool get isWindows => os == 'windows';

  /// The platform this process runs on.
  ///
  /// Throws a [BuildPlatformException] on any other, since a build cannot
  /// check libraries it cannot load.
  static BuildPlatform get host => switch (Abi.current()) {
    Abi.macosArm64 => macosArm64,
    Abi.windowsArm64 => windowsArm64,
    Abi.windowsX64 => windowsX64,
    final abi => throw BuildPlatformException(
      'a build runs on macOS on arm64 or on Windows on arm64 or x64, '
      'not $abi',
    ),
  };

  /// The platform [id] names, or null when no platform has that id.
  static BuildPlatform? parse(Object? id) =>
      values.where((platform) => platform.id == id).firstOrNull;

  /// The runtime's file name: `libtree-sitter.dylib` on macOS and
  /// `tree-sitter.dll` on Windows, the names each platform's own build of
  /// tree-sitter gives it.
  String get runtimeFileName => libraryFileName('tree-sitter');

  /// The file name of the library named [name] (a grammar's language id,
  /// or `tree-sitter`): `lib<name>.dylib` on macOS, `<name>.dll` on
  /// Windows, as `package:code_assets`'s `OS.dylibFileName` spells it.
  String libraryFileName(String name) =>
      isWindows ? '$name.dll' : 'lib$name.dylib';

  /// Whether [path] names a library of this platform.
  bool isLibrary(String path) => path.endsWith(isWindows ? '.dll' : '.dylib');

  /// The release asset a build for this platform packs.
  String get releaseArchiveName => 'grammars-$id.tar.gz';

  /// The archive a `--dry-run` build packs: the bytes a tagged build of the
  /// same commit packs, under a name no release asset has.
  String get dryRunArchiveName => 'grammars-$id.dry-run.tar.gz';

  /// The clang target triple of a Windows platform.
  String get windowsTarget => switch (this) {
    windowsArm64 => 'aarch64-pc-windows-msvc',
    windowsX64 => 'x86_64-pc-windows-msvc',
    macosArm64 => throw StateError('$id is not a Windows platform'),
  };

  /// The directory name of this platform's architecture under the MSVC
  /// tools' and the Windows SDK's `lib`.
  String get windowsLibArch => switch (this) {
    windowsArm64 => 'arm64',
    windowsX64 => 'x64',
    macosArm64 => throw StateError('$id is not a Windows platform'),
  };
}
