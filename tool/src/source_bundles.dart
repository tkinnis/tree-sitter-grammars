/// Packs and unpacks the source bundles: one gzip-compressed tar per pinned
/// repository, holding the tree `git archive` writes at its pin.
///
/// Every build compiles from the bundles it unpacks, and a release attaches
/// them, so the release can be rebuilt from its own assets after an
/// upstream rewrites or deletes the commit it pinned.
library;

import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'git.dart';
import 'grammar_pins.dart';
import 'toolchain.dart';

/// The directory of `output/` holding the bundles.
const sourcesDirectoryName = 'sources';

/// The runtime's repository.
const runtimeRepositoryUrl = 'https://github.com/tree-sitter/tree-sitter';

/// Thrown when a bundle cannot be packed, is not the one recorded, or
/// cannot be unpacked.
final class SourceBundleException implements Exception {
  const SourceBundleException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// One repository the build compiles from, at its pin.
final class PinnedSource {
  const PinnedSource({
    required this.name,
    required this.url,
    required this.commit,
  });

  /// The repository's name, which names its directory under `build/src/`.
  final String name;
  final String url;
  final String commit;

  /// The bundle's file name, which is also its top-level directory with
  /// `.tar.gz` removed.
  String get bundleName => '$name-$commit.tar.gz';
}

/// The runtime, then every grammar repository in `grammars.json` order.
List<PinnedSource> pinnedSources(
  Toolchain toolchain,
  List<Map<String, Object?>> entries,
) => [
  PinnedSource(
    name: repositoryName(runtimeRepositoryUrl),
    url: runtimeRepositoryUrl,
    commit: toolchain.treeSitterCommit,
  ),
  for (final entry in entries)
    if (entry['url'] case final String url)
      PinnedSource(
        name: repositoryName(url),
        url: url,
        commit: entry['commit']! as String,
      ),
];

/// The executables every bundle is packed and unpacked with, named by path
/// so a different `tar` or `gzip` earlier on `PATH` never writes the bytes.
const _tar = '/usr/bin/tar';
const _gzip = '/usr/bin/gzip';

/// Writes the tree of [commit] in the git repository [directory] to
/// [bundle], under a top-level directory named for [bundle].
///
/// `git archive` runs cut off from the user's and the system's
/// configuration, with no attributes file, no line-ending conversion and a
/// `tar.umask` of 0022; `gzip -n -9` compresses it with no name or time.
/// The same commit therefore packs to the same bytes with the same git and
/// gzip. [environment] replaces this process's environment as the one
/// git's isolation starts from.
Future<void> packBundle(
  String directory,
  String commit,
  String bundle, {
  Map<String, String>? environment,
}) async {
  final prefix = _prefix(bundle);
  final tar = '$bundle.tar';
  await runIsolatedGit(directory, [
    '-c',
    'core.attributesFile=/dev/null',
    '-c',
    'core.autocrlf=false',
    '-c',
    'core.eol=lf',
    '-c',
    'tar.umask=0022',
    'archive',
    '--format=tar',
    '--prefix=$prefix/',
    '--output=${p.absolute(tar)}',
    commit,
  ], environment: environment);
  try {
    final gzip = await Process.start(_gzip, ['-n', '-9', '-c', tar]);
    final written = gzip.stdout.pipe(File(bundle).openWrite());
    final errors = gzip.stderr.transform(utf8.decoder).join();
    final exitCode = await gzip.exitCode;
    await written;
    if (exitCode != 0) {
      throw SourceBundleException(
        'gzip $tar exited $exitCode: ${await errors}',
      );
    }
  } finally {
    File(tar).deleteSync();
  }
}

/// Unpacks [bundle] into [destination], which must not exist yet, without
/// its top-level directory.
Future<void> unpackBundle(String bundle, String destination) async {
  if (FileSystemEntity.typeSync(destination) != FileSystemEntityType.notFound) {
    throw SourceBundleException('$destination already exists');
  }
  Directory(destination).createSync(recursive: true);
  final result = await Process.run(_tar, [
    '-xzf',
    bundle,
    '-C',
    destination,
    '--strip-components',
    '1',
  ]);
  if (result.exitCode != 0) {
    throw SourceBundleException(
      'tar could not unpack $bundle: ${result.stderr}',
    );
  }
}

/// The commit id `git archive` recorded in [bundle]'s first header, read by
/// `git get-tar-commit-id`, or null when it records none.
Future<String?> bundleCommit(String bundle) async {
  final head = BytesBuilder();
  await for (final chunk in File(bundle).openRead().transform(gzip.decoder)) {
    head.add(chunk);
    if (head.length >= 1024) break;
  }
  final git = await Process.start('git', ['get-tar-commit-id']);
  git.stdin.add(head.takeBytes());
  await git.stdin.close();
  final commit = git.stdout.transform(utf8.decoder).join();
  await git.stderr.drain<void>();
  return await git.exitCode == 0 ? (await commit).trim() : null;
}

/// The sha256 of the file at [path].
Future<String> fileSha256(String path) async {
  final result = await Process.run('/usr/bin/shasum', ['-a', '256', path]);
  if (result.exitCode != 0) {
    throw SourceBundleException('shasum $path failed: ${result.stderr}');
  }
  return (result.stdout as String).split(' ').first;
}

String _prefix(String bundle) {
  final name = p.basename(bundle);
  if (!name.endsWith('.tar.gz')) {
    throw SourceBundleException('$bundle does not end in .tar.gz');
  }
  return name.substring(0, name.length - '.tar.gz'.length);
}

/// What `build_info.json` records of one bundle.
Map<String, Object?> bundleRecord(PinnedSource source, String sha256) => {
  'url': source.url,
  'commit': source.commit,
  'file': '$sourcesDirectoryName/${source.bundleName}',
  'sha256': sha256,
};

/// Checks the bundle for [source] in [directory] against [recorded], the
/// `sources` object of the `build_info.json` that release recorded, and
/// returns its sha256.
///
/// The bundle must be named for [source]'s pin, `recorded` must name the
/// same commit and file, its sha256 must be the recorded one, and the
/// commit id in its header must be the pin. Throws a
/// [SourceBundleException] naming the first requirement that fails.
Future<String> checkRecordedBundle(
  String directory,
  PinnedSource source,
  Map<String, Object?> recorded,
) async {
  final record = recorded[source.name];
  if (record is! Map<String, Object?>) {
    throw SourceBundleException(
      '${source.name}: build_info.json records no bundle',
    );
  }
  final file = '$sourcesDirectoryName/${source.bundleName}';
  if (record['commit'] != source.commit || record['file'] != file) {
    throw SourceBundleException(
      '${source.name}: build_info.json records ${record['file']} at '
      '${record['commit']}; the pin is ${source.commit}',
    );
  }
  final bundle = p.join(directory, source.bundleName);
  if (!File(bundle).existsSync()) {
    throw SourceBundleException('${source.name}: no $bundle');
  }
  final digest = await fileSha256(bundle);
  if (digest != record['sha256']) {
    throw SourceBundleException(
      '$bundle has sha256 $digest; build_info.json records '
      '${record['sha256']}',
    );
  }
  final commit = await bundleCommit(bundle);
  if (commit != source.commit) {
    throw SourceBundleException(
      '$bundle records commit $commit in its header, not ${source.commit}',
    );
  }
  return digest;
}
