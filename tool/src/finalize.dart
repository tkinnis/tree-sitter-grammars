/// Publishes a draft release once every platform's archive is attached.
///
/// A published release is immutable: it never gains or changes an asset.
/// So the draft must hold exactly the assets the release is to have, each
/// with the digest it was packed with, before it is published, and is read
/// back once it is.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import 'attach.dart';
import 'build_platform.dart';
import 'github.dart';
import 'tar.dart';

final _sha256Pattern = RegExp(r'^[0-9a-f]{64}$');

/// Publishes the draft release [tag], whose archives for [platforms] are
/// attached, and returns the sha256 of each archive by platform id.
///
/// Before anything changes, the tag on GitHub must be the annotated tag
/// object [tagObject], naming [commit]; the release must be a draft; it
/// must hold exactly the archive and `.sha256` of every platform in
/// [platforms], `build_info.json` and the bundles that records, and no
/// other asset; and GitHub's digest of each must be the sha256 recorded
/// for it. The release notes then gain a table of the archives, and the
/// draft is published in the same request. Afterwards the tag must still
/// name [commit], and GitHub must report the release immutable, with the
/// assets it had and their digests. Throws a [PublishException] naming the
/// first step that fails.
Future<Map<String, String>> finalizeRelease({
  required String tag,
  required String tagObject,
  required String commit,
  required List<BuildPlatform> platforms,
  ProcessRunner run = runProcess,
}) async {
  if (platforms.isEmpty) {
    throw const PublishException(
      'checking the platforms: --require names no platform',
    );
  }
  final gh = githubCli(run);
  Future<void> requireTag(String when) => requirePushedTag(
    gh,
    tag: tag,
    tagObject: tagObject,
    commit: commit,
    when: when,
  );

  await requireTag('before finalizing');
  final draft = await findDraft(gh, tag, commit);
  final info = await _recordedInfo(gh, draft, tag);
  final bundles = _bundleAssets(info);
  _requireAssetNames(draft, tag, platforms, bundles.keys);
  final archives = await _requireDigests(gh, draft, platforms, bundles);
  final glibc = <BuildPlatform, String>{
    for (final platform in platforms)
      if (platform.isLinux)
        platform: await _glibcRequirement(gh, draft, platform, archives),
  };
  final patch = await gh([
    'api',
    'repos/$releaseRepository/releases/${draft.id}',
    '-X',
    'PATCH',
    '-F',
    'draft=false',
    '-f',
    'body=${draft.body}\n\n${_archiveTable(platforms, archives, glibc)}',
  ]);
  if (patch.exitCode != 0) {
    throw PublishException(
      'publishing: gh api PATCH $tag failed: ${errorText(patch)}',
    );
  }
  await requireTag('after finalizing');
  final published = await readRelease(gh, draft.id);
  final problems = [
    if (published.draft) 'reading back: $tag is still a draft',
    if (!published.immutable) 'reading back: $tag is not reported immutable',
    ...assetProblems(draft.assets, published),
  ];
  if (problems.isNotEmpty) throw PublishException(problems.join('\n'));
  return {for (final platform in platforms) platform.id: archives[platform]!};
}

/// The draft's `build_info.json`, parsed.
Future<Map<String, Object?>> _recordedInfo(
  GitHubCli gh,
  GitHubRelease draft,
  String tag,
) async {
  final asset = draft.asset('build_info.json');
  if (asset == null) {
    throw PublishException('checking the assets: build_info.json is missing');
  }
  return parseBuildInfo(
    await downloadAsset(gh, asset.id),
    "the draft's build_info.json",
  );
}

/// The file name of each bundle `build_info.json` [info] records, mapped
/// to its sha256.
Map<String, String> _bundleAssets(Map<String, Object?> info) => {
  for (final key in ['sources', 'generated'])
    if (info[key] case final Map<String, Object?> records)
      for (final record in records.values)
        if (record case {'file': final String file, 'sha256': final String sha})
          p.basename(file): sha,
};

/// Requires [draft] to hold exactly the assets a release of [platforms]
/// has: `build_info.json`, [bundles], and each platform's archive and
/// `.sha256`.
void _requireAssetNames(
  GitHubRelease draft,
  String tag,
  List<BuildPlatform> platforms,
  Iterable<String> bundles,
) {
  final expected = {
    'build_info.json',
    ...bundles,
    for (final platform in platforms) ...[
      platform.releaseArchiveName,
      '${platform.releaseArchiveName}.sha256',
    ],
  };
  final present = {for (final asset in draft.assets) asset.name};
  final problems = [
    for (final name in expected)
      if (!present.contains(name)) 'checking the assets: $name is missing',
    for (final name in present)
      if (!expected.contains(name))
        'checking the assets: $name is not an asset of $tag',
  ];
  if (problems.isNotEmpty) throw PublishException(problems.join('\n'));
}

/// Requires the digest GitHub reports of each asset to be the sha256
/// recorded for it, and returns each platform's archive sha256.
///
/// An archive's is the one in its `.sha256`; a bundle's the one in
/// `build_info.json`; a `.sha256`'s the digest of its own content.
Future<Map<BuildPlatform, String>> _requireDigests(
  GitHubCli gh,
  GitHubRelease draft,
  List<BuildPlatform> platforms,
  Map<String, String> bundles,
) async {
  final problems = <String>[];
  final archives = <BuildPlatform, String>{};
  void compare(String name, String expected, String recorded) {
    final digest = draft.asset(name)?.digest;
    if (digest != 'sha256:$expected') {
      problems.add(
        'checking the digests: $name: GitHub reports $digest, $recorded',
      );
    }
  }

  for (final platform in platforms) {
    final name = platform.releaseArchiveName;
    final sidecar = draft.asset('$name.sha256')!;
    final bytes = await downloadAsset(gh, sidecar.id);
    final tokens = String.fromCharCodes(bytes).trim().split(RegExp(r'\s+'));
    if (tokens.length != 2 ||
        tokens[1] != name ||
        !_sha256Pattern.hasMatch(tokens[0])) {
      problems.add(
        'checking the digests: $name.sha256 holds '
        '"${String.fromCharCodes(bytes).trim()}", not "<sha256>  $name"',
      );
      continue;
    }
    archives[platform] = tokens[0];
    compare(name, tokens[0], 'its .sha256 holds sha256:${tokens[0]}');
    compare(
      '$name.sha256',
      dartSha256(bytes),
      'its content is sha256:${dartSha256(bytes)}',
    );
  }
  for (final MapEntry(key: name, value: sha256) in bundles.entries) {
    compare(name, sha256, 'build_info.json records $sha256');
  }
  if (problems.isNotEmpty) throw PublishException(problems.join('\n'));
  return archives;
}

/// The `glibcRequirement` the Linux archive of [platform] records in its
/// own `build_info.json`, read from the archive as GitHub serves it.
///
/// The downloaded bytes must have the sha256 [archives] holds for it.
Future<String> _glibcRequirement(
  GitHubCli gh,
  GitHubRelease draft,
  BuildPlatform platform,
  Map<BuildPlatform, String> archives,
) async {
  final name = platform.releaseArchiveName;
  final bytes = await downloadAsset(gh, draft.asset(name)!.id);
  if (dartSha256(bytes) != archives[platform]) {
    throw PublishException(
      'reading the notes: $name as downloaded has sha256 '
      '${dartSha256(bytes)}, not ${archives[platform]}',
    );
  }
  final scratch = Directory.systemTemp.createTempSync('finalize');
  try {
    final file = File(p.join(scratch.path, name))..writeAsBytesSync(bytes);
    final recorded = await tarGzFile(file.path, 'build_info.json');
    final info = recorded == null
        ? null
        : parseBuildInfo(recorded, "$name's build_info.json");
    return switch (info?['glibcRequirement']) {
      final String glibc when glibc.isNotEmpty => glibc,
      _ => throw PublishException(
        'reading the notes: $name records no glibcRequirement',
      ),
    };
  } finally {
    scratch.deleteSync(recursive: true);
  }
}

/// The notes' table of [platforms]' archives: each one's sha256 and, for a
/// Linux archive, the glibc its libraries need.
String _archiveTable(
  List<BuildPlatform> platforms,
  Map<BuildPlatform, String> archives,
  Map<BuildPlatform, String> glibc,
) {
  final rows = [
    for (final platform in platforms)
      '| ${platform.id} | `${archives[platform]}` |'
          '${glibc[platform] == null ? '' : ' ${glibc[platform]}'} |',
  ];
  return [
    '| Platform | sha256 | glibc (and later) |',
    '| --- | --- | --- |',
    ...rows,
    '',
  ].join('\n');
}
