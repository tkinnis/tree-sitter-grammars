/// What a `build_info.json` read back must record: the build of a release
/// at a commit, for a platform, and on Linux the linker, C library and
/// GCC runtime the build linked with.
///
/// Every reader of a record downloaded or unpacked, `--sources` before
/// anything compiles, the bundles it supplies, an archive `--attach` or
/// `--finalize` checks and `tool/check_release.dart`, asks these, so each
/// refuses a record for the same reasons in the same words.
library;

import 'build_platform.dart';

/// Every way [info], a `build_info.json` read from [source], records
/// another build than that of [release] at [commit] and, when [platform]
/// is given, for it; empty when it records the same.
///
/// A release's commit is `repository.commit`, the commit the build ran at.
/// With no [release], the commit alone is checked: every published
/// `build_info.json` records its tag, and the release tagged at [commit]
/// is the one whose assets a build of no release may read. A record of a
/// Linux [platform] must also hold every field [linuxToolchainKeys] names.
List<String> buildRecordProblems(
  Map<Object?, Object?> info, {
  required String source,
  required String? release,
  required String commit,
  BuildPlatform? platform,
}) {
  final repository = info['repository'];
  final recordedCommit = repository is Map ? repository['commit'] : null;
  return [
    if (release != null && info['release'] != release)
      '$source records the release ${info['release']}, not $release',
    if (recordedCommit != commit)
      '$source records the commit $recordedCommit, not $commit',
    if (platform != null && info['platform'] != platform.id)
      '$source records the platform ${info['platform']}, not ${platform.id}'
    else if (platform != null && platform.isLinux)
      ...linuxToolchainRecordProblems(info, source: source),
  ];
}

/// The fields under `toolchain` a Linux build's `build_info.json` records
/// of the linker, the C library and GCC's runtime it linked with, beside
/// clang.
const linuxToolchainKeys = [
  'linker',
  'linkerPackage',
  'linkerPath',
  'linkerResolvedPath',
  'hostLibc',
  'hostLibcBanner',
  'hostLibcPath',
  'hostLibcDev',
  'hostLibcDevPath',
  'gccRuntime',
  'gccRuntimePath',
];

/// Every field of [linuxToolchainKeys] that [info], a Linux build's
/// `build_info.json` read from [source], does not record as a string that
/// is not empty; empty when it records each.
List<String> linuxToolchainRecordProblems(
  Map<Object?, Object?> info, {
  String source = 'build_info.json',
}) {
  final toolchain = info['toolchain'];
  if (toolchain is! Map) return ['$source records no toolchain'];
  return [
    for (final key in linuxToolchainKeys)
      if (toolchain[key] is! String || (toolchain[key] as String).isEmpty)
        '$source records no toolchain.$key',
  ];
}
