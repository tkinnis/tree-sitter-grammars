/// Publishes a packed release to GitHub with the GitHub CLI, once: a release
/// that already exists is never changed.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// The GitHub repository releases are published to.
const releaseRepository = 'tkinnis/tree-sitter-grammars';

/// Runs [executable] with [arguments] and returns its result.
///
/// A typedef so tests can answer `gh` without the network.
typedef ProcessRunner =
    Future<ProcessResult> Function(String executable, List<String> arguments);

Future<ProcessResult> _run(String executable, List<String> arguments) =>
    Process.run(executable, arguments);

/// Thrown when a release cannot be, or was not, published as packed.
final class PublishException implements Exception {
  const PublishException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Creates the GitHub release [tag] of [releaseRepository] with [assets],
/// whose sha256 digests are the values of the map, and the notes in
/// [notesFile].
///
/// Refuses when the release exists already, so an asset is never replaced.
/// `gh release create --verify-tag` refuses a tag not yet pushed. After the
/// upload, every asset's digest as GitHub reports it must be the local
/// one. Throws a [PublishException] naming the first step that fails.
Future<void> publishRelease({
  required String tag,
  required Map<String, String> assets,
  required String notesFile,
  ProcessRunner run = _run,
}) async {
  Future<ProcessResult> gh(List<String> arguments) async {
    try {
      return await run('gh', arguments);
    } on ProcessException catch (error) {
      throw PublishException('gh could not run: ${error.message}');
    }
  }

  final existing = await gh([
    'release',
    'view',
    tag,
    '--repo',
    releaseRepository,
    '--json',
    'tagName',
  ]);
  if (existing.exitCode == 0) {
    throw PublishException(
      'release $tag exists on $releaseRepository; a release is published '
      'once and never changed',
    );
  }
  if (!'${existing.stderr}'.contains('release not found')) {
    throw PublishException(
      'gh release view $tag failed: ${'${existing.stderr}'.trim()}',
    );
  }
  final created = await gh([
    'release',
    'create',
    tag,
    '--repo',
    releaseRepository,
    '--verify-tag',
    '--title',
    tag,
    '--notes-file',
    notesFile,
    ...assets.keys,
  ]);
  if (created.exitCode != 0) {
    throw PublishException(
      'gh release create $tag failed: ${'${created.stderr}'.trim()}',
    );
  }
  final listed = await gh([
    'api',
    'repos/$releaseRepository/releases/tags/$tag',
    '--jq',
    '[.assets[] | {name, digest}]',
  ]);
  if (listed.exitCode != 0) {
    throw PublishException(
      'published $tag, but could not read its assets back: '
      '${'${listed.stderr}'.trim()}',
    );
  }
  final published = {
    for (final asset in jsonDecode('${listed.stdout}') as List)
      (asset as Map<String, Object?>)['name']: asset['digest'],
  };
  final problems = [
    for (final MapEntry(key: path, value: sha256) in assets.entries)
      if (published[p.basename(path)] != 'sha256:$sha256')
        '${p.basename(path)}: GitHub reports ${published[p.basename(path)]}, '
            'the local file is sha256:$sha256',
  ];
  if (published.length != assets.length) {
    problems.add(
      'GitHub lists ${published.length} assets; '
      '${assets.length} were uploaded',
    );
  }
  if (problems.isNotEmpty) {
    throw PublishException(
      [
        'published $tag, but its assets are not the packed files:',
        ...problems,
      ].join('\n  '),
    );
  }
}

/// The release notes: the runtime, every pinned grammar and the sha256 of
/// each attached file, from `build_info.json` [info] and [archiveSha256].
String releaseNotes(Map<String, Object?> info, String archiveSha256) {
  final treeSitter = info['treeSitter']! as Map<String, Object?>;
  final sources = info['sources']! as Map<String, Object?>;
  final rows = [
    for (final MapEntry(key: name, value: record) in sources.entries)
      if (record case final Map<String, Object?> record)
        '| $name | `${record['commit']}` | '
            '`${p.basename('${record['file']}')}` | `${record['sha256']}` |',
  ];
  return 'tree-sitter ${treeSitter['tag']} (${treeSitter['commit']}), '
      'macOS ${info['deploymentTarget']} and later on arm64.\n\n'
      '`grammars-macos-arm64.tar.gz`: sha256 `$archiveSha256`.\n\n'
      'Every repository the release compiles from, at the commit it pins, '
      'is attached as the source bundle named below; the README says how '
      'to rebuild the release from them.\n\n'
      '| Repository | Commit | Source bundle | sha256 |\n'
      '| --- | --- | --- | --- |\n'
      '${rows.join('\n')}\n';
}
