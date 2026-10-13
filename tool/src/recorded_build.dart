/// What a `build_info.json` read back must record: the build of a release
/// at a commit, for a platform.
///
/// Every reader of a record downloaded or unpacked, `--sources` before
/// anything compiles, the bundles it supplies and an archive `--attach` or
/// `--finalize` checks, asks this, so each refuses a record for the same
/// reasons in the same words.
library;

import 'build_platform.dart';

/// Every way [info], a `build_info.json` read from [source], records
/// another build than that of [release] at [commit] and, when [platform]
/// is given, for it; empty when it records the same.
///
/// A release's commit is `repository.commit`, the commit the build ran at.
/// With no [release], the commit alone is checked: every published
/// `build_info.json` records its tag, and the release tagged at [commit]
/// is the one whose assets a build of no release may read.
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
      '$source records the platform ${info['platform']}, not ${platform.id}',
  ];
}
