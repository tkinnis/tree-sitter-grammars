/// Reads `tool/toolchain.json`: the tree-sitter runtime, the tree-sitter CLI
/// and the macOS target every build uses, and the CLI each Windows
/// architecture generates with.
library;

import 'dart:convert';
import 'dart:io';

import 'build_platform.dart';

/// The tree-sitter CLI release asset one platform runs, and its sha256.
typedef CliAsset = ({String asset, String sha256});

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
    required this.treeSitterFilesSha256,
    required this.cliVersion,
    required this.cliAsset,
    required this.cliSha256,
    required this.arch,
    required this.deploymentTarget,
    this.runtimeExtraNotices = const [],
    this.windowsCli = const {},
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
      treeSitterFilesSha256: _string(
        treeSitter,
        'treeSitter.filesSha256',
        RegExp(r'^[0-9a-f]{64}$'),
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
      runtimeExtraNotices: _paths(treeSitter, 'treeSitter.extraNotices'),
      windowsCli: _windowsCli(root),
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

  /// The digest of the files [treeSitterCommit]'s tree holds, as
  /// `files_digest.dart` computes it.
  final String treeSitterFilesSha256;

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

  /// The runtime's compiled sources, relative to its repository root, that
  /// carry a licence statement of their own beyond its licence files:
  /// `treeSitter.extraNotices`, empty when absent.
  final List<String> runtimeExtraNotices;

  /// The CLI release asset each Windows architecture runs, by
  /// [BuildPlatform.arch]: `windows.<arch>` of `toolchain.json`, empty when
  /// it has no `windows` object. [cliVersion] is the release of each.
  final Map<String, CliAsset> windowsCli;

  /// [treeSitterTag] without its leading `v`, as the runtime's Makefile
  /// declares it.
  String get runtimeVersion => treeSitterTag.substring(1);

  /// Where the CLI release asset is downloaded from.
  Uri get cliUrl => _releaseAsset(cliAsset);

  /// The CLI release asset a build on [platform] runs: [cliAsset] on
  /// macOS, and the asset `windows.<arch>` names on Windows.
  ///
  /// Throws a [ToolchainException] for a Windows architecture
  /// `toolchain.json` pins no CLI for.
  CliAsset cliFor(BuildPlatform platform) {
    if (!platform.isWindows) return (asset: cliAsset, sha256: cliSha256);
    return windowsCli[platform.arch] ??
        (throw ToolchainException(
          'windows.${platform.arch} pins no CLI for ${platform.id}',
        ));
  }

  /// Where [platform]'s CLI release asset is downloaded from.
  Uri cliUrlFor(BuildPlatform platform) =>
      _releaseAsset(cliFor(platform).asset);

  Uri _releaseAsset(String asset) => Uri.parse(
    'https://github.com/tree-sitter/tree-sitter/'
    'releases/download/v$cliVersion/$asset',
  );
}

/// The optional `windows` object of [root]: for each Windows architecture
/// a build targets, the CLI release asset it generates with and its sha256.
Map<String, CliAsset> _windowsCli(Object? root) {
  if (root is! Map<String, Object?> || root['windows'] == null) {
    return const {};
  }
  final windows = _object(root, 'windows');
  final architectures = {
    for (final platform in BuildPlatform.values)
      if (platform.isWindows) platform.arch,
  };
  final assets = <String, CliAsset>{};
  for (final arch in windows.keys) {
    if (!architectures.contains(arch)) {
      throw ToolchainException(
        'windows.$arch is no Windows architecture a build targets; '
        'those are ${architectures.join(', ')}',
      );
    }
    final pin = _object(windows, arch);
    assets[arch] = (
      asset: _string(
        pin,
        'windows.$arch.cliAsset',
        RegExp('^tree-sitter-windows-$arch\\.gz\$'),
      ),
      sha256: _string(
        pin,
        'windows.$arch.cliSha256',
        RegExp(r'^[0-9a-f]{64}$'),
      ),
    );
  }
  return assets;
}

Map<String, Object?> _object(Object? root, String key) {
  final value = root is Map<String, Object?> ? root[key] : null;
  if (value is! Map<String, Object?>) {
    throw ToolchainException('$key must be an object');
  }
  return value;
}

/// The optional list of paths [field] names in [object]; empty when it is
/// absent.
List<String> _paths(Map<String, Object?> object, String field) {
  final value = object[field.split('.').last];
  if (value == null) return const [];
  if (value is! List || value.any((path) => path is! String || path.isEmpty)) {
    throw ToolchainException('$field must be a list of paths');
  }
  return value.cast<String>();
}

String _string(Map<String, Object?> object, String field, RegExp pattern) {
  final value = object[field.split('.').last];
  if (value is! String || !pattern.hasMatch(value)) {
    throw ToolchainException('$field must match ${pattern.pattern}');
  }
  return value;
}
