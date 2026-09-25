/// Reads `tool/toolchain.json`: the tree-sitter runtime, the tree-sitter CLI
/// and the macOS target every build uses.
library;

import 'dart:convert';
import 'dart:io';

/// Thrown when `tool/toolchain.json` is missing a field or holds a value
/// that cannot be right.
final class ToolchainException implements Exception {
  const ToolchainException(this.message);

  final String message;

  @override
  String toString() => 'toolchain.json: $message';
}

/// The pinned toolchain.
final class Toolchain {
  const Toolchain({
    required this.treeSitterTag,
    required this.treeSitterCommit,
    required this.cliVersion,
    required this.cliAsset,
    required this.cliSha256,
    required this.arch,
    required this.deploymentTarget,
  });

  /// Parses and checks the contents of `tool/toolchain.json`.
  ///
  /// Throws a [ToolchainException] naming the first field that is missing or
  /// malformed.
  factory Toolchain.parse(String json) {
    final Object? root;
    try {
      root = jsonDecode(json);
    } on FormatException catch (error) {
      throw ToolchainException('not valid JSON: ${error.message}');
    }
    final treeSitter = _object(root, 'treeSitter');
    final cli = _object(root, 'treeSitterCli');
    final macos = _object(root, 'macos');
    final toolchain = Toolchain(
      treeSitterTag: _string(
        treeSitter,
        'treeSitter.tag',
        RegExp(r'^v\d+\.\d+\.\d+$'),
      ),
      treeSitterCommit: _string(
        treeSitter,
        'treeSitter.commit',
        RegExp(r'^[0-9a-f]{40}$'),
      ),
      cliVersion: _string(
        cli,
        'treeSitterCli.version',
        RegExp(r'^\d+\.\d+\.\d+$'),
      ),
      cliAsset: _string(cli, 'treeSitterCli.asset', RegExp(r'^[\w.-]+\.gz$')),
      cliSha256: _string(
        cli,
        'treeSitterCli.sha256',
        RegExp(r'^[0-9a-f]{64}$'),
      ),
      arch: _string(macos, 'macos.arch', RegExp(r'^arm64$')),
      deploymentTarget: _string(
        macos,
        'macos.deploymentTarget',
        RegExp(r'^\d+\.\d+$'),
      ),
    );
    if (toolchain.runtimeVersion != toolchain.cliVersion) {
      throw ToolchainException(
        'treeSitterCli.version '
        '${toolchain.cliVersion} differs from treeSitter.tag '
        '${toolchain.treeSitterTag}',
      );
    }
    return toolchain;
  }

  /// Reads `tool/toolchain.json` under [repositoryRoot].
  factory Toolchain.load(String repositoryRoot) => Toolchain.parse(
    File('$repositoryRoot/tool/toolchain.json').readAsStringSync(),
  );

  /// The runtime's release tag, for example `v0.27.0`.
  final String treeSitterTag;

  /// The 40-hex commit [treeSitterTag] names.
  final String treeSitterCommit;

  /// The CLI release that generates grammars which commit no `parser.c`.
  final String cliVersion;

  /// The CLI release asset's file name.
  final String cliAsset;

  /// The sha256 of [cliAsset], checked before the CLI runs.
  final String cliSha256;

  /// The one architecture every library is built for.
  final String arch;

  /// The minimum macOS version every library declares.
  final String deploymentTarget;

  /// [treeSitterTag] without its leading `v`, as the runtime's Makefile
  /// declares it.
  String get runtimeVersion => treeSitterTag.substring(1);

  /// Where the CLI release asset is downloaded from.
  Uri get cliUrl => Uri.parse(
    'https://github.com/tree-sitter/tree-sitter/'
    'releases/download/v$cliVersion/$cliAsset',
  );
}

Map<String, Object?> _object(Object? root, String key) {
  final value = root is Map<String, Object?> ? root[key] : null;
  if (value is! Map<String, Object?>) {
    throw ToolchainException('$key must be an object');
  }
  return value;
}

String _string(Map<String, Object?> object, String field, RegExp pattern) {
  final value = object[field.split('.').last];
  if (value is! String || !pattern.hasMatch(value)) {
    throw ToolchainException('$field must match ${pattern.pattern}');
  }
  return value;
}
