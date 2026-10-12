import 'dart:convert';
import 'dart:io';

import 'package:checks/checks.dart';
import 'package:test/test.dart';

import '../tool/src/build_platform.dart';
import '../tool/src/toolchain.dart';

Map<String, Object?> _valid() => {
  'treeSitter': {
    'tag': 'v0.27.0',
    'commit': '6070dbfefd326bd735e5683eb128cc1b57dad0c0',
    'filesSha256':
        '8284859e50207152e5df621e49086ea169020c47ef342489f5f8c06b7082f2ea',
  },
  'treeSitterCli': {
    'version': '0.27.0',
    'asset': 'tree-sitter-macos-arm64.gz',
    'sha256':
        '70f7573b2b2e5371a5b58cc5227d2ad981fd5374596b9874e770af486060774e',
  },
  'macos': {'arch': 'arm64', 'deploymentTarget': '13.0'},
};

void main() {
  test('the committed toolchain.json parses', () {
    final toolchain = Toolchain.parse(
      File('tool/toolchain.json').readAsStringSync(),
    );

    check(toolchain)
      ..has((t) => t.treeSitterTag, 'tag').equals('v0.27.0')
      ..has((t) => t.runtimeVersion, 'runtimeVersion').equals('0.27.0')
      ..has((t) => t.deploymentTarget, 'deploymentTarget').equals('13.0')
      ..has((t) => t.cliUrl.toString(), 'cliUrl').equals(
        'https://github.com/tree-sitter/tree-sitter/releases/download/'
        'v0.27.0/tree-sitter-macos-arm64.gz',
      );
  });

  test('an abbreviated runtime commit is refused', () {
    final json = _valid();
    (json['treeSitter']! as Map<String, Object?>)['commit'] = '6070dbfe';

    check(() => Toolchain.parse(jsonEncode(json)))
        .throws<ToolchainException>()
        .has((e) => e.message, 'message')
        .startsWith('treeSitter.commit');
  });

  test('a CLI version other than the runtime tag is refused', () {
    final json = _valid();
    (json['treeSitterCli']! as Map<String, Object?>)['version'] = '0.26.3';

    check(() => Toolchain.parse(jsonEncode(json)))
        .throws<ToolchainException>()
        .has((e) => e.message, 'message')
        .contains('differs from treeSitter.tag');
  });

  test('the committed toolchain.json pins a CLI for each Windows '
      'architecture', () {
    final toolchain = Toolchain.parse(
      File('tool/toolchain.json').readAsStringSync(),
    );

    check(
      toolchain.cliFor(BuildPlatform.macosArm64).asset,
    ).equals('tree-sitter-macos-arm64.gz');
    check(
      toolchain.cliFor(BuildPlatform.windowsArm64).asset,
    ).equals('tree-sitter-windows-arm64.gz');
    check(
      toolchain.cliFor(BuildPlatform.windowsX64).asset,
    ).equals('tree-sitter-windows-x64.gz');
    check(toolchain.cliUrlFor(BuildPlatform.windowsArm64).toString()).equals(
      'https://github.com/tree-sitter/tree-sitter/releases/download/'
      'v0.27.0/tree-sitter-windows-arm64.gz',
    );
  });

  test('the committed toolchain.json pins a CLI for Linux on arm64', () {
    final toolchain = Toolchain.parse(
      File('tool/toolchain.json').readAsStringSync(),
    );

    check(toolchain.cliFor(BuildPlatform.linuxArm64)).equals((
      asset: 'tree-sitter-linux-arm64.gz',
      sha256:
          '3a35a2dd961ad842384e982c75daf792c01d1a67e442fc3914d4de37bd8a59cb',
    ));
    check(toolchain.cliUrlFor(BuildPlatform.linuxArm64).toString()).equals(
      'https://github.com/tree-sitter/tree-sitter/releases/download/'
      'v0.27.0/tree-sitter-linux-arm64.gz',
    );
  });

  test('a toolchain.json with no windows or linux object builds for macOS '
      'only', () {
    final toolchain = Toolchain.parse(jsonEncode(_valid()));

    check(toolchain.cliPins).isEmpty();
    check(
      () => toolchain.cliFor(BuildPlatform.windowsArm64),
    ).throws<ToolchainException>();
    check(() => toolchain.cliFor(BuildPlatform.linuxArm64))
        .throws<ToolchainException>()
        .has((e) => e.message, 'message')
        .startsWith('linux.arm64 pins no CLI');
  });

  test('a Linux architecture no build targets is refused', () {
    final json = _valid()
      ..['linux'] = {
        'x86': {'cliAsset': 'tree-sitter-linux-x86.gz', 'cliSha256': '0' * 64},
      };

    check(() => Toolchain.parse(jsonEncode(json)))
        .throws<ToolchainException>()
        .has((e) => e.message, 'message')
        .startsWith('linux.x86 is no Linux architecture');
  });

  test('a Linux CLI asset of another operating system is refused', () {
    final json = _valid()
      ..['linux'] = {
        'arm64': {
          'cliAsset': 'tree-sitter-macos-arm64.gz',
          'cliSha256': '0' * 64,
        },
      };

    check(() => Toolchain.parse(jsonEncode(json)))
        .throws<ToolchainException>()
        .has((e) => e.message, 'message')
        .startsWith('linux.arm64.cliAsset');
  });

  test('a Windows architecture no build targets is refused', () {
    final json = _valid()
      ..['windows'] = {
        'arm': {
          'cliAsset': 'tree-sitter-windows-arm.gz',
          'cliSha256': '0' * 64,
        },
      };

    check(() => Toolchain.parse(jsonEncode(json)))
        .throws<ToolchainException>()
        .has((e) => e.message, 'message')
        .startsWith('windows.arm is no Windows architecture');
  });

  test('a Windows CLI asset of another architecture is refused', () {
    final json = _valid()
      ..['windows'] = {
        'arm64': {
          'cliAsset': 'tree-sitter-windows-x64.gz',
          'cliSha256': '0' * 64,
        },
      };

    check(() => Toolchain.parse(jsonEncode(json)))
        .throws<ToolchainException>()
        .has((e) => e.message, 'message')
        .startsWith('windows.arm64.cliAsset');
  });

  test('an architecture other than arm64 is refused', () {
    final json = _valid();
    (json['macos']! as Map<String, Object?>)['arch'] = 'x86_64';

    check(() => Toolchain.parse(jsonEncode(json)))
        .throws<ToolchainException>()
        .has((e) => e.message, 'message')
        .startsWith('macos.arch');
  });
}
