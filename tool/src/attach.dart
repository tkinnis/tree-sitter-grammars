/// Attaches a platform's archive to the draft release macOS created.
///
/// GitHub's immutable releases never gain an asset once published, so a
/// release is a draft until every platform's archive is attached to it:
/// `--publish` on macOS creates the draft, `--attach` on Linux and Windows
/// adds each of theirs, and `--finalize` publishes it (see `finalize.dart`).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'build_platform.dart';
import 'github.dart';
import 'tar.dart';

/// Requires the `build_info.json` [info], read from [source], to record
/// the build of [release] at [commit]; when [platform] is given, for it.
///
/// A release's commit is `repository.commit`, the commit the build ran at.
/// Throws a [PublishException] naming the first field that differs.
void requireBuildRecord(
  Map<String, Object?> info, {
  required String release,
  required String commit,
  required String source,
  BuildPlatform? platform,
}) {
  String record(Object? value) => '$value';
  final repository = info['repository'];
  final recordedCommit = repository is Map ? repository['commit'] : null;
  final problems = [
    if (info['release'] != release)
      '$source records the release ${record(info['release'])}, '
          'not $release',
    if (recordedCommit != commit)
      '$source records the commit ${record(recordedCommit)}, not $commit',
    if (platform != null && info['platform'] != platform.id)
      '$source records the platform ${record(info['platform'])}, '
          'not ${platform.id}',
  ];
  if (problems.isNotEmpty) throw PublishException(problems.join('; '));
}

/// The sha256 of every source bundle and bundle of generated sources the
/// `build_info.json` [info] records, by repository (and, for a generated
/// bundle, `<grammar> (generated)`).
Map<String, String> bundleDigests(Map<String, Object?> info) => {
  for (final (key, suffix) in [('sources', ''), ('generated', ' (generated)')])
    if (info[key] case final Map<String, Object?> records)
      for (final MapEntry(key: name, value: record) in records.entries)
        '$name$suffix': '${(record as Map<String, Object?>)['sha256']}',
};

/// Parses [bytes] as the JSON object `build_info.json` is.
Map<String, Object?> parseBuildInfo(List<int> bytes, String source) {
  try {
    final info = jsonDecode(utf8.decode(bytes));
    if (info is Map<String, Object?>) return info;
  } on FormatException {
    // Falls through to the message below.
  }
  throw PublishException('$source is not a JSON object');
}

/// Requires the bundles [archive] records to be the ones [release] records.
///
/// A platform's archive records the sha256 of the source bundles it
/// compiled from, which are the ones the draft holds, so the archive built
/// from another set of bundles is refused.
void requireSameBundles(
  Map<String, Object?> archive,
  Map<String, Object?> release,
) {
  final own = bundleDigests(archive);
  final theirs = bundleDigests(release);
  final problems = [
    for (final name in {...own.keys, ...theirs.keys})
      if (own[name] != theirs[name])
        'checking the sources: $name: the archive records '
            "${own[name] ?? 'none'}, the release's build_info.json "
            "${theirs[name] ?? 'none'}",
  ];
  if (problems.isNotEmpty) throw PublishException(problems.join('\n'));
}

/// Finds the one release of [tag], a draft nobody has published, whose
/// target is not another commit than [commit].
///
/// Throws a [PublishException] naming `finding the draft` when there is
/// none, more than one, or it is published, immutable or targeted
/// elsewhere. A target that is not a commit id is a branch, which the tag
/// check outranks: the tag names the commit.
Future<GitHubRelease> findDraft(GitHubCli gh, String tag, String commit) async {
  final releases = await releasesOfTag(gh, tag);
  String refusal(String reason) => 'finding the draft: $reason';
  if (releases.isEmpty) {
    throw PublishException(
      refusal(
        'no release of $tag on $releaseRepository; create it with '
        '--publish on macOS',
      ),
    );
  }
  if (releases.length > 1) {
    throw PublishException(
      refusal('${releases.length} releases of $tag exist; there is one'),
    );
  }
  final release = releases.single;
  if (!release.draft) {
    throw PublishException(refusal('$tag is not a draft'));
  }
  if (release.immutable) {
    throw PublishException(refusal('$tag is immutable'));
  }
  if (RegExp(r'^[0-9a-f]{40}$').hasMatch(release.target) &&
      release.target != commit) {
    throw PublishException(
      refusal('$tag targets ${release.target}, not $commit'),
    );
  }
  return release;
}

/// Uploads the archive [outputDirectory] holds for [platform], and its
/// `.sha256`, to the draft release [tag].
///
/// The archive and its `.sha256` must be consistent, and the archive's own
/// `build_info.json` must record [tag], [commit] and [platform], and the
/// source bundles the draft's `build_info.json` records. The tag on GitHub
/// must be the annotated tag object [tagObject], naming [commit], before
/// and after. The release must be a draft that holds neither asset;
/// nothing is replaced (no `--clobber`). Afterwards GitHub must report
/// each new asset's digest as the local sha256 and every earlier asset
/// unchanged. Throws a [PublishException] naming the first step that
/// fails.
Future<void> attachArchive({
  required String tag,
  required String tagObject,
  required String commit,
  required BuildPlatform platform,
  required String outputDirectory,
  ProcessRunner run = runProcess,
}) async {
  if (platform.isMacos) {
    throw const PublishException(
      'checking the platform: the macOS build creates the draft with '
      '--publish; --attach is for Linux and Windows',
    );
  }
  final gh = githubCli(run);
  final archive = p.join(outputDirectory, platform.releaseArchiveName);
  final sidecar = '$archive.sha256';
  final uploaded = {
    p.basename(archive): await _checkedArchive(archive, sidecar),
    p.basename(sidecar): await dartFileSha256(sidecar),
  };
  final info = await _embeddedInfo(archive, tag, commit, platform);
  Future<void> requireTag(String when) => requirePushedTag(
    gh,
    tag: tag,
    tagObject: tagObject,
    commit: commit,
    when: when,
  );

  await requireTag('before attaching');
  final draft = await findDraft(gh, tag, commit);
  for (final path in [archive, sidecar]) {
    if (draft.asset(p.basename(path)) != null) {
      throw PublishException(
        'finding the draft: $tag holds ${p.basename(path)} already; an '
        'asset is never replaced',
      );
    }
  }
  final recorded = draft.asset('build_info.json');
  if (recorded == null) {
    throw PublishException(
      'finding the draft: $tag has no build_info.json to compare the '
      "archive's sources with",
    );
  }
  requireSameBundles(
    info,
    parseBuildInfo(
      await downloadAsset(gh, recorded.id),
      "the draft's build_info.json",
    ),
  );
  final upload = await gh([
    'release',
    'upload',
    tag,
    '--repo',
    releaseRepository,
    archive,
    sidecar,
  ]);
  if (upload.exitCode != 0) {
    throw PublishException(
      'uploading: gh release upload $tag failed: ${errorText(upload)}',
    );
  }
  await requireTag('after attaching');
  await _readBack(gh, draft, uploaded);
}

/// The sha256 of [archive], which its [sidecar] must name.
Future<String> _checkedArchive(String archive, String sidecar) async {
  if (!File(archive).existsSync() || !File(sidecar).existsSync()) {
    throw PublishException(
      'checking the archive: ${p.basename(archive)} and '
      '${p.basename(sidecar)} are not both in ${p.dirname(archive)}',
    );
  }
  final sha256 = await dartFileSha256(archive);
  final expected = '$sha256  ${p.basename(archive)}';
  final held = File(sidecar).readAsStringSync().trim();
  if (held != expected) {
    throw PublishException(
      'checking the archive: ${p.basename(sidecar)} holds "$held", '
      'not "$expected"',
    );
  }
  return sha256;
}

/// The `build_info.json` inside [archive], checked to record the build of
/// [tag] at [commit] for [platform].
Future<Map<String, Object?>> _embeddedInfo(
  String archive,
  String tag,
  String commit,
  BuildPlatform platform,
) async {
  final bytes = await tarGzFile(archive, 'build_info.json');
  if (bytes == null) {
    throw PublishException(
      'checking the archive: ${p.basename(archive)} holds no build_info.json',
    );
  }
  final info = parseBuildInfo(bytes, "the archive's build_info.json");
  try {
    requireBuildRecord(
      info,
      release: tag,
      commit: commit,
      platform: platform,
      source: "its build_info.json",
    );
  } on PublishException catch (error) {
    throw PublishException('checking the archive: $error');
  }
  return info;
}

/// Reads [draft] back and requires each of [uploaded] to have the digest
/// GitHub reports, and every asset [draft] held to be unchanged.
Future<void> _readBack(
  GitHubCli gh,
  GitHubRelease draft,
  Map<String, String> uploaded,
) async {
  final after = await readRelease(gh, draft.id);
  final problems = <String?>[
    for (final MapEntry(key: name, value: sha256) in uploaded.entries)
      if (after.asset(name)?.digest != 'sha256:$sha256')
        '$name: GitHub reports ${after.asset(name)?.digest}, the local file '
            'is sha256:$sha256',
    for (final before in draft.assets)
      switch (after.asset(before.name)) {
        null => '${before.name} is gone',
        final now when now.digest != before.digest =>
          '${before.name} was ${before.digest}, GitHub reports ${now.digest}',
        _ => null,
      },
    for (final asset in after.assets)
      if (draft.asset(asset.name) == null && !uploaded.containsKey(asset.name))
        '${asset.name} is an asset nobody uploaded',
  ];
  final found = problems.nonNulls;
  if (found.isNotEmpty) {
    throw PublishException(
      [for (final problem in found) 'reading back: $problem'].join('\n'),
    );
  }
}
