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
import 'recorded_build.dart';
import 'tar.dart';

/// Requires the `build_info.json` [info], read from [source], to record
/// the build of [release] at [commit]; when [platform] is given, for it,
/// and for Linux with every toolchain field of its linker and C library.
///
/// Throws a [PublishException] naming every problem
/// [buildRecordProblems] finds.
void requireBuildRecord(
  Map<String, Object?> info, {
  required String release,
  required String commit,
  required String source,
  BuildPlatform? platform,
}) {
  final problems = buildRecordProblems(
    info,
    source: source,
    release: release,
    commit: commit,
    platform: platform,
  );
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
/// target is [commit] itself.
///
/// Throws a [PublishException] naming `finding the draft` when there is
/// none, more than one, or it is published, immutable or targeted
/// elsewhere. `--publish` creates the draft with `--target` set to the
/// built commit, so a branch name as the target is refused too.
Future<GitHubRelease> findDraft(GitHubCli gh, String tag, String commit) async {
  final releases = await releasesOfTag(gh, tag);
  String refusal(String reason) => 'finding the draft: $reason';
  if (releases.length != 1) {
    throw PublishException(
      refusal(
        releases.isEmpty
            ? 'no release of $tag on $releaseRepository; create it with '
                  '--publish on macOS'
            : '${releases.length} releases of $tag exist; there is one',
      ),
    );
  }
  final release = releases.single;
  if (!release.draft) {
    throw PublishException(refusal('$tag is not a draft'));
  }
  if (release.immutable) {
    throw PublishException(refusal('$tag is immutable'));
  }
  if (release.target != commit) {
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
  Duration pollDelay = const Duration(seconds: 2),
  int pollTries = 5,
}) async {
  if (platform.isMacos) {
    throw const PublishException(
      'checking the platform: the macOS build creates the draft with '
      '--publish; --attach is for Linux and Windows',
    );
  }
  final gh = githubCli(run);
  if (outputDirectory.contains('#')) {
    throw PublishException(
      'checking the archive: $outputDirectory holds #, which gh release '
      'upload reads as the start of an asset label',
    );
  }
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
  if (uploaded.keys.any((name) => draft.asset(name) != null)) {
    final settled = await _settled(
      gh,
      draft,
      uploaded.keys,
      pollTries,
      pollDelay,
    );
    if (!uploaded.keys.every(
      (name) => _isUploaded(settled.asset(name), uploaded[name]!),
    )) {
      final held = [
        for (final name in uploaded.keys)
          if (settled.asset(name) != null) name,
      ];
      throw PublishException(
        'finding the draft: $tag holds ${held.join(' and ')}, which is not '
        'the local file, complete with its digest; remove it with '
        '${held.map((name) => deleteAssetCommand(tag, name)).join(' and ')}',
      );
    }
    await requireTag('after attaching');
    return;
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
  final after = await _settled(
    gh,
    draft,
    uploaded.keys,
    pollTries,
    pollDelay,
    allowAbsent: false,
  );
  final problems = assetProblems(
    draft.assets,
    after,
    uploaded: uploaded,
    tolerated: (name) => _otherPlatformAsset(name, platform),
  );
  if (problems.isNotEmpty) throw PublishException(problems.join('\n'));
}

/// The `gh release delete-asset` command that removes the asset [name] of
/// the draft [tag].
String deleteAssetCommand(String tag, String name) =>
    'gh release delete-asset $tag $name --repo $releaseRepository';

/// Whether [asset] is complete and has GitHub's digest [sha256].
bool _isUploaded(ReleaseAsset? asset, String sha256) =>
    asset != null &&
    asset.state == 'uploaded' &&
    asset.digest == 'sha256:$sha256';

/// Whether [asset] is complete and has a digest: GitHub computes the
/// digest a moment after an upload.
bool _isSettled(ReleaseAsset? asset) =>
    asset != null && asset.state == 'uploaded' && asset.digest != null;

/// [release], read again up to [tries] times, [delay] apart, until each
/// asset in [names] is complete with a digest; assets absent from the
/// release count as settled when [allowAbsent].
Future<GitHubRelease> _settled(
  GitHubCli gh,
  GitHubRelease release,
  Iterable<String> names,
  int tries,
  Duration delay, {
  bool allowAbsent = true,
}) async {
  var current = release;
  for (var attempt = 1; attempt <= tries; attempt++) {
    final settled = names.every((name) {
      final asset = current.asset(name);
      return asset == null ? allowAbsent : _isSettled(asset);
    });
    if (settled || attempt == tries) return current;
    await Future<void>.delayed(delay);
    current = await readRelease(gh, release.id);
  }
  return current;
}

/// Whether [name] is the archive or `.sha256` of a platform other than
/// [platform], which may be attached while this one is.
bool _otherPlatformAsset(String name, BuildPlatform platform) => [
  for (final other in BuildPlatform.values)
    if (other != platform) ...[
      other.releaseArchiveName,
      '${other.releaseArchiveName}.sha256',
    ],
].contains(name);

/// The sha256 of [archive], which its [sidecar] must name.
Future<String> _checkedArchive(String archive, String sidecar) async {
  if (!File(archive).existsSync() || !File(sidecar).existsSync()) {
    throw PublishException(
      'checking the archive: ${p.basename(archive)} and '
      '${p.basename(sidecar)} are not both in ${p.dirname(archive)}',
    );
  }
  final sha256 = await dartFileSha256(archive);
  final expected = '$sha256  ${p.basename(archive)}\n';
  final held = File(sidecar).readAsStringSync();
  if (held != expected) {
    throw PublishException(
      'checking the archive: ${p.basename(sidecar)} holds ${jsonEncode(held)}, '
      'not ${jsonEncode(expected)}',
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
  final info = await archiveBuildInfo(archive);
  try {
    requireBuildRecord(
      info,
      release: tag,
      commit: commit,
      platform: platform,
      source: 'its build_info.json',
    );
  } on PublishException catch (error) {
    throw PublishException('checking the archive: $error');
  }
  return info;
}

/// The `build_info.json` inside the archive at [archive].
///
/// Throws a [PublishException] when the archive cannot be read or is no
/// well-formed gzip-compressed tar stream, when it holds no
/// `build_info.json`, or one that is not a JSON object.
Future<Map<String, Object?>> archiveBuildInfo(String archive) async {
  final List<int>? bytes;
  try {
    bytes = await tarGzRootFile(archive, 'build_info.json');
  } on TarException catch (error) {
    throw PublishException('checking the archive: $error');
  }
  if (bytes == null) {
    throw PublishException(
      'checking the archive: ${p.basename(archive)} holds no build_info.json',
    );
  }
  return parseBuildInfo(bytes, "the archive's build_info.json");
}

/// Every way [after] differs from [before] plus [uploaded], the sha256 of
/// each asset added by name: an asset that changed, went or came, or an
/// uploaded one whose digest GitHub reports as another.
List<String> assetProblems(
  List<ReleaseAsset> before,
  GitHubRelease after, {
  Map<String, String> uploaded = const {},
  bool Function(String name) tolerated = _none,
}) {
  ReleaseAsset? earlier(String name) =>
      before.where((asset) => asset.name == name).firstOrNull;
  return <String?>[
    for (final MapEntry(key: name, value: sha256) in uploaded.entries)
      if (after.asset(name)?.digest != 'sha256:$sha256')
        'reading back: $name: GitHub reports ${after.asset(name)?.digest}, '
            'the local file is sha256:$sha256'
      else if (after.asset(name)?.state != 'uploaded')
        'reading back: $name is in the state ${after.asset(name)?.state}',
    for (final asset in before)
      switch (after.asset(asset.name)) {
        null => 'reading back: ${asset.name} is gone',
        final now when now.digest != asset.digest || now.id != asset.id =>
          'reading back: ${asset.name} was ${asset.digest}, GitHub reports '
              '${now.digest}',
        _ => null,
      },
    for (final asset in after.assets)
      if (earlier(asset.name) == null &&
          !uploaded.containsKey(asset.name) &&
          !tolerated(asset.name))
        'reading back: ${asset.name} is an asset nobody uploaded',
  ].nonNulls.toList();
}

bool _none(String name) => false;

/// Requires the `build_info.json` in [bundles], the directory `--sources`
/// names, to record the build of [release] at [commit].
///
/// Checked before anything compiles: bundles of another release, or of
/// another commit than the one the archive is built at, are never packed
/// into an archive that is then attached to [release].
void requireSourcesRecord(String bundles, String release, String commit) {
  final file = File(p.join(bundles, 'build_info.json'));
  if (!file.existsSync()) {
    throw PublishException(
      'checking --sources: $bundles holds no build_info.json; download the '
      'assets of the draft into one directory',
    );
  }
  try {
    requireBuildRecord(
      parseBuildInfo(file.readAsBytesSync(), file.path),
      release: release,
      commit: commit,
      source: file.path,
    );
  } on PublishException catch (error) {
    throw PublishException('checking --sources: $error');
  }
}
