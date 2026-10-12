import 'dart:io';

import 'package:checks/checks.dart';
import 'package:test/test.dart';

import '../tool/src/build_platform.dart';

void main() {
  test('names the libraries and archive of macOS as it always has', () {
    const macos = BuildPlatform.macosArm64;

    check(macos.id).equals('macos-arm64');
    check(macos.runtimeFileName).equals('libtree-sitter.dylib');
    check(macos.libraryFileName('c-sharp')).equals('libc-sharp.dylib');
    check(macos.releaseArchiveName).equals('grammars-macos-arm64.tar.gz');
    check(
      macos.dryRunArchiveName,
    ).equals('grammars-macos-arm64.dry-run.tar.gz');
  });

  test('names the libraries and archives of Windows as Windows does', () {
    check(BuildPlatform.windowsArm64.id).equals('windows-arm64');
    check(BuildPlatform.windowsArm64.runtimeFileName).equals('tree-sitter.dll');
    check(
      BuildPlatform.windowsArm64.libraryFileName('c-sharp'),
    ).equals('c-sharp.dll');
    check(
      BuildPlatform.windowsArm64.releaseArchiveName,
    ).equals('grammars-windows-arm64.tar.gz');
    check(
      BuildPlatform.windowsX64.releaseArchiveName,
    ).equals('grammars-windows-x64.tar.gz');
    check(
      BuildPlatform.windowsArm64.windowsTarget,
    ).equals('aarch64-pc-windows-msvc');
    check(
      BuildPlatform.windowsX64.windowsTarget,
    ).equals('x86_64-pc-windows-msvc');
  });

  test('names the libraries and archive of Linux as Linux does', () {
    const linux = BuildPlatform.linuxArm64;

    check(linux.id).equals('linux-arm64');
    check(linux.osName).equals('Linux');
    check(linux.runtimeFileName).equals('libtree-sitter.so');
    check(linux.libraryFileName('c-sharp')).equals('libc-sharp.so');
    check(linux.isLibrary('dylibs/c/libc.so')).isTrue();
    check(linux.isLibrary('dylibs/c/libc.dylib')).isFalse();
    check(linux.releaseArchiveName).equals('grammars-linux-arm64.tar.gz');
    check(
      linux.dryRunArchiveName,
    ).equals('grammars-linux-arm64.dry-run.tar.gz');
    check(linux.linuxTarget).equals('aarch64-linux-gnu');
    check(() => linux.windowsTarget).throws<StateError>();
    check(() => BuildPlatform.windowsArm64.linuxTarget).throws<StateError>();
  });

  test('each operating system is one of the three, and only one', () {
    for (final platform in BuildPlatform.values) {
      check(
        [
          platform.isMacos,
          platform.isLinux,
          platform.isWindows,
        ].where((it) => it),
      ).length.equals(1);
    }
    check(BuildPlatform.isAnyLibrary('x/libx.so')).isTrue();
    check(BuildPlatform.isAnyLibrary('x/x.dll')).isTrue();
    check(BuildPlatform.isAnyLibrary('x/libx.dylib')).isTrue();
    check(BuildPlatform.isAnyLibrary('x/config.json')).isFalse();
  });

  test('parses each id and nothing else', () {
    for (final platform in BuildPlatform.values) {
      check(BuildPlatform.parse(platform.id)).equals(platform);
    }
    check(BuildPlatform.parse('linux-x64')).isNull();
    check(BuildPlatform.parse(null)).isNull();
  });

  test('the host is the platform this process runs on', () {
    final host = BuildPlatform.host;

    check(host.isWindows).equals(Platform.isWindows);
    check(host.os).equals(Platform.operatingSystem);
  }, testOn: 'mac-os || linux || windows');
}
