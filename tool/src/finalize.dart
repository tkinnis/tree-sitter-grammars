/// Publishes a draft release once every platform's archive is attached.
///
/// A published release is immutable: it never gains or changes an asset.
/// So the draft must hold exactly the assets the release is to have, each
/// with the digest it was packed with and each an archive of this release
/// and commit, before it is published; nothing found wrong afterwards can
/// be put right.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'attach.dart';
import 'build_platform.dart';
import 'github.dart';
import 'tar.dart';

/// A `.sha256` file as `--release` writes it: the lowercase hex sha256, two
/// spaces, the archive's name, one newline.
RegExp _sidecarPattern(String name) =>
    RegExp('^([0-9a-f]{64})  ${RegExp.escape(name)}\n\$');

/// Publishes the draft release [tag], whose archives for [platforms] are
/// attached, and returns the sha256 of each archive by platform id.
///
/// [platforms] and [absent] together name every platform the repository
/// builds, each once; an [absent] platform has no archive in this release
/// and the notes say so. Immutable releases must be enabled on the
/// repository, or the published release could still change.
///
/// Before anything changes, the tag on GitHub must be the annotated tag
/// object [tagObject], naming [commit]; the release must be a draft
/// targeting [commit]; `build_info.json` must record this release and
/// commit and every bundle; the draft must hold exactly the archive and
/// `.sha256` of every platform in [platforms], `build_info.json` and the
/// bundles that records, all complete, and no other asset; GitHub's digest
/// of each must be the sha256 recorded for it; and every archive, as
/// downloaded, must have that sha256 and record this release, commit,
/// platform and bundles. Just before publishing, the tag and the draft are
/// read again and must be as checked. The release notes then gain a table
/// of the archives, and the draft is published in the same request.
/// Afterwards the tag must still name [commit], and GitHub must report the
/// release immutable, with the assets it had and their digests; a failure
/// there leaves a published release whose tag is burned. Throws a
/// [PublishException] naming the first step that fails.
Future<Map<String, String>> finalizeRelease({
  required String tag,
  required String tagObject,
  required String commit,
  required List<BuildPlatform> platforms,
  List<BuildPlatform> absent = const [],
  ProcessRunner run = runProcess,
}) async {
  _requireEveryPlatform(platforms, absent);
  final gh = githubCli(run);
  Future<void> requireTag(String when) => requirePushedTag(
    gh,
    tag: tag,
    tagObject: tagObject,
    commit: commit,
    when: when,
  );

  await _requireImmutableReleases(gh);
  await requireTag('before finalizing');
  final draft = await findDraft(gh, tag, commit);
  final info = await _recordedInfo(gh, draft, tag, commit);
  final bundles = _bundleAssets(info);
  _requireAssetNames(draft, tag, platforms, bundles.keys);
  final archives = await _requireDigests(gh, draft, platforms, bundles);
  final glibc = await _requireArchives(
    gh,
    draft,
    platforms,
    archives,
    info,
    tag,
    commit,
  );
  await requireTag('before publishing');
  _requireUnchanged(draft, await readRelease(gh, draft.id), tag);
  final patch = await gh([
    'api',
    'repos/$releaseRepository/releases/${draft.id}',
    '-X',
    'PATCH',
    '-F',
    'draft=false',
    '-f',
    'body=${draft.body}\n\n'
        '${_archiveTable(platforms, absent, archives, glibc)}',
  ]);
  if (patch.exitCode != 0) {
    throw PublishException(
      'publishing: gh api PATCH $tag failed: ${errorText(patch)}; read the '
      'release before trying again, since the request may have been applied',
    );
  }
  try {
    await requireTag('after finalizing');
    final published = await readRelease(gh, draft.id);
    final problems = [
      if (published.draft) 'reading back: $tag is still a draft',
      if (!published.immutable) 'reading back: $tag is not reported immutable',
      ...assetProblems(draft.assets, published),
    ];
    if (problems.isNotEmpty) throw PublishException(problems.join('\n'));
  } on PublishException catch (error) {
    throw PublishException(
      '$tag is published and immutable, but it is not the release that was '
      'checked:\n$error\nthe tag $tag is burned: do not pin these digests '
      'in hook/grammars_config.json, fix the cause and release the next '
      'version',
    );
  }
  return {for (final platform in platforms) platform.id: archives[platform]!};
}

/// Requires [platforms] and [absent] to be disjoint and together every
/// platform the repository builds.
void _requireEveryPlatform(
  List<BuildPlatform> platforms,
  List<BuildPlatform> absent,
) {
  if (platforms.isEmpty) {
    throw const PublishException(
      'checking the platforms: --require names no platform',
    );
  }
  final problems = [
    for (final platform in BuildPlatform.values)
      if (platforms.contains(platform) && absent.contains(platform))
        'checking the platforms: ${platform.id} is both required and '
            'allowed missing'
      else if (!platforms.contains(platform) && !absent.contains(platform))
        'checking the platforms: ${platform.id} is neither required nor '
            'allowed missing; name it in --require, or in --allow-missing '
            'when this release has no archive for it',
  ];
  if (problems.isNotEmpty) throw PublishException(problems.join('\n'));
}

/// Requires immutable releases to be enabled on [releaseRepository].
Future<void> _requireImmutableReleases(GitHubCli gh) async {
  final result = await gh([
    'api',
    'repos/$releaseRepository/immutable-releases',
  ]);
  if (result.exitCode != 0) {
    throw PublishException('checking immutable releases: ${errorText(result)}');
  }
  final Object? answer;
  try {
    answer = jsonDecode(outputText(result.stdout));
  } on FormatException {
    throw const PublishException(
      'checking immutable releases: GitHub answered something other than JSON',
    );
  }
  if (answer is! Map || answer['enabled'] != true) {
    throw PublishException(
      'checking immutable releases: they are not enabled on '
      '$releaseRepository; a published release could still change',
    );
  }
}

/// The draft's `build_info.json`, parsed and checked to record [tag] at
/// [commit].
Future<Map<String, Object?>> _recordedInfo(
  GitHubCli gh,
  GitHubRelease draft,
  String tag,
  String commit,
) async {
  final asset = draft.asset('build_info.json');
  if (asset == null) {
    throw PublishException('checking the assets: build_info.json is missing');
  }
  final info = parseBuildInfo(
    await downloadAsset(gh, asset.id),
    "the draft's build_info.json",
  );
  try {
    requireBuildRecord(
      info,
      release: tag,
      commit: commit,
      source: "the draft's build_info.json",
    );
  } on PublishException catch (error) {
    throw PublishException('checking the draft: $error');
  }
  return info;
}

/// The file name of each bundle `build_info.json` [info] records, mapped
/// to its sha256.
///
/// Throws a [PublishException] when it records no source bundle or no
/// bundle of generated sources, when a record is not a file name and a
/// sha256, or when two records name one file.
Map<String, String> _bundleAssets(Map<String, Object?> info) {
  final bundles = <String, String>{};
  for (final (key, what) in [
    ('sources', 'sources'),
    ('generated', 'generated sources'),
  ]) {
    final records = info[key];
    if (records is! Map<String, Object?> || records.isEmpty) {
      throw PublishException(
        'checking the draft: build_info.json records no $what',
      );
    }
    for (final MapEntry(key: name, value: record) in records.entries) {
      if (record case {
        'file': final String file,
        'sha256': final String sha,
      } when file.isNotEmpty && sha.isNotEmpty) {
        if (bundles.containsKey(p.basename(file))) {
          throw PublishException(
            'checking the draft: build_info.json records '
            '${p.basename(file)} twice',
          );
        }
        bundles[p.basename(file)] = sha;
      } else {
        throw PublishException(
          'checking the draft: build_info.json records a malformed bundle '
          '$key.$name',
        );
      }
    }
  }
  return bundles;
}

/// Requires [draft] to hold exactly the assets a release of [platforms]
/// has: `build_info.json`, [bundles], and each platform's archive and
/// `.sha256`, each complete.
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
    for (final asset in draft.assets)
      if (!expected.contains(asset.name))
        'checking the assets: ${asset.name} is not an asset of $tag; remove '
            'it with ${deleteAssetCommand(tag, asset.name)}'
      else if (asset.state != 'uploaded')
        'checking the assets: ${asset.name} is in the state ${asset.state}',
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
    final bytes = await downloadAsset(gh, draft.asset('$name.sha256')!.id);
    final text = utf8.decode(bytes, allowMalformed: true);
    final match = _sidecarPattern(name).firstMatch(text);
    if (match == null) {
      problems.add(
        'checking the digests: $name.sha256 holds ${jsonEncode(text)}, not '
        '"<lowercase sha256>  $name" and a newline',
      );
      continue;
    }
    final sha256 = match.group(1)!;
    archives[platform] = sha256;
    compare(name, sha256, 'its .sha256 holds sha256:$sha256');
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

/// Downloads every archive of [platforms] and requires it to be the bytes
/// [archives] holds the sha256 of, to record [tag] at [commit] for its
/// platform, and to record the bundles [info] does; returns the glibc each
/// Linux archive records it needs.
Future<Map<BuildPlatform, String>> _requireArchives(
  GitHubCli gh,
  GitHubRelease draft,
  List<BuildPlatform> platforms,
  Map<BuildPlatform, String> archives,
  Map<String, Object?> info,
  String tag,
  String commit,
) async {
  final glibc = <BuildPlatform, String>{};
  final scratch = Directory.systemTemp.createTempSync('finalize');
  try {
    for (final platform in platforms) {
      final name = platform.releaseArchiveName;
      final bytes = await downloadAsset(gh, draft.asset(name)!.id);
      if (dartSha256(bytes) != archives[platform]) {
        throw PublishException(
          'checking the archives: $name as downloaded has sha256 '
          '${dartSha256(bytes)}, not ${archives[platform]}',
        );
      }
      final file = File(p.join(scratch.path, name))..writeAsBytesSync(bytes);
      final own = await archiveBuildInfo(file.path);
      try {
        requireBuildRecord(
          own,
          release: tag,
          commit: commit,
          platform: platform,
          source: 'its build_info.json',
        );
        requireSameBundles(own, info);
      } on PublishException catch (error) {
        throw PublishException('checking the archives: $name: $error');
      }
      if (platform.isLinux) {
        glibc[platform] = switch (own['glibcRequirement']) {
          final String requirement when requirement.isNotEmpty => requirement,
          _ => throw PublishException(
            'checking the archives: $name records no glibcRequirement',
          ),
        };
      }
    }
  } finally {
    scratch.deleteSync(recursive: true);
  }
  return glibc;
}

/// Requires [now], the release read just before it is published, to be
/// [checked], the draft that was checked: still a draft with the same
/// target and exactly the same assets, each the same upload (by id) with
/// the same digest and state.
void _requireUnchanged(GitHubRelease checked, GitHubRelease now, String tag) {
  final problems = [
    if (!now.draft) 'before publishing: $tag is no longer a draft',
    if (now.target != checked.target)
      'before publishing: $tag targets ${now.target} now, not '
          '${checked.target}',
    for (final asset in checked.assets)
      switch (now.asset(asset.name)) {
        null => 'before publishing: ${asset.name} is gone',
        final later when later.id != asset.id =>
          'before publishing: ${asset.name} is a different asset now',
        final later when later.digest != asset.digest =>
          'before publishing: ${asset.name} was ${asset.digest}, GitHub '
              'reports ${later.digest}',
        final later when later.state != asset.state =>
          'before publishing: ${asset.name} is in the state ${later.state} '
              'now',
        _ => null,
      },
    for (final asset in now.assets)
      if (checked.asset(asset.name) == null)
        'before publishing: ${asset.name} is an asset nobody checked',
  ].nonNulls;
  if (problems.isNotEmpty) throw PublishException(problems.join('\n'));
}

/// The notes' table of the archives of [platforms], each one's sha256 and,
/// for a Linux archive, the glibc its libraries need, and a row for each
/// of [absent] saying this release has none.
String _archiveTable(
  List<BuildPlatform> platforms,
  List<BuildPlatform> absent,
  Map<BuildPlatform, String> archives,
  Map<BuildPlatform, String> glibc,
) {
  final rows = [
    for (final platform in platforms)
      '| ${platform.id} | `${archives[platform]}` |'
          '${glibc[platform] == null ? '' : ' ${glibc[platform]}'} |',
    for (final platform in absent) '| ${platform.id} | not in this release | |',
  ];
  return [
    '| Platform | sha256 | glibc (and later) |',
    '| --- | --- | --- |',
    ...rows,
    '',
  ].join('\n');
}
