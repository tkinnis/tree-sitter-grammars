import 'dart:convert';
import 'dart:io';

import 'package:checks/checks.dart';
import 'package:test/test.dart';

import '../tool/src/toolchain.dart';

Map<String, Object?> _valid() => {
  'treeSitter': {
    'tag': 'v0.27.0',
    'commit': '6070dbfefd326bd735e5683eb128cc1b57dad0c0',
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

  test('an architecture other than arm64 is refused', () {
    final json = _valid();
    (json['macos']! as Map<String, Object?>)['arch'] = 'x86_64';

    check(() => Toolchain.parse(jsonEncode(json)))
        .throws<ToolchainException>()
        .has((e) => e.message, 'message')
        .startsWith('macos.arch');
  });
}
