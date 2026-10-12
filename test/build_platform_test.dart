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
  }, testOn: 'mac-os || windows');
}
