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
import 'source_patches.dart';
import 'tar.dart';
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
    required this.filesSha256,
    this.patches = const [],
    this.patchedSha256,
  });

  /// The repository's name, which names its directory under `build/src/`.
  final String name;
  final String url;
  final String commit;

  /// The digest of the files [commit]'s tree holds, which the pin records.
  final String filesSha256;

  /// The patches applied to the tree before it compiles, each a path
  /// relative to this repository's root, in the order they apply.
  final List<String> patches;

  /// The digest of the files the tree holds once [patches] are applied,
  /// which the pin records beside them; null when there are none.
  final String? patchedSha256;

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
    filesSha256: toolchain.treeSitterFilesSha256,
  ),
  for (final entry in entries)
    if (entry['url'] case final String url)
      PinnedSource(
        name: repositoryName(url),
        url: url,
        commit: entry['commit']! as String,
        filesSha256: entry['filesSha256']! as String,
        patches: entryPatches(entry),
        patchedSha256: entry['patchedSha256'] as String?,
      ),
];

/// The git every bundle is written with, named by path so a different
/// `git` earlier on `PATH` never writes the bytes.
///
/// On macOS it is `/usr/bin/git`, which runs the git of the Xcode that
/// `xcrun` selects, honouring `DEVELOPER_DIR`, as the build's clang does.
/// Windows has no git of fixed path, so there it is the first `git.exe` on
/// `PATH`, resolved once to its absolute path, which `build_info.json`
/// records beside its version.
String get bundleGit => Platform.isWindows ? _windowsGit : '/usr/bin/git';

/// The tar a build on macOS or Linux packs and unpacks with; a build on
/// Windows does both in Dart, with `tar.dart`. Tests name one that does not
/// exist, to show that a refused bundle never reaches it.
String tarExecutable = '/usr/bin/tar';

/// The gzip a build on macOS or Linux packs with.
const _gzip = '/usr/bin/gzip';

final String _windowsGit = _onPath('git.exe');

/// The absolute path of the first [executable] in a directory `PATH`
/// lists; throws a [SourceBundleException] when there is none.
String _onPath(String executable) {
  for (final directory in (Platform.environment['PATH'] ?? '').split(';')) {
    if (directory.isEmpty) continue;
    final candidate = p.join(directory, executable);
    if (File(candidate).existsSync()) return p.normalize(candidate);
  }
  throw SourceBundleException('no $executable on PATH');
}

/// What a build on Windows records as the gzip and the tar that write its
/// bundles and archive: `dart:io`'s zlib, whose output can change with the
/// Dart release, and `tool/src/tar.dart`'s ustar writer.
String get _dartGzip =>
    'dart:io GZipCodec level 9, Dart ${Platform.version.split(' ').first}';
const _dartTar = 'tool/src/tar.dart ustar';

/// The first line of `--version` of each tool whose output lands in the
/// bundles or the archive, by name: [bundleGit], which writes each bundle's
/// tar, and `/usr/bin/gzip` and `/usr/bin/tar`, which compress the bundles
/// and pack the archive.
///
/// On Windows, gzip and tar are Dart's, recorded as [_dartGzip] and
/// [_dartTar].
Future<Map<String, String>> packingToolVersions() async {
  if (Platform.isWindows) {
    final git = await Process.run(bundleGit, ['--version']);
    if (git.exitCode != 0) {
      throw SourceBundleException(
        '$bundleGit --version exited ${git.exitCode}: ${git.stderr}',
      );
    }
    return {
      'git': '${git.stdout}'.trim().split('\n').first.trim(),
      'gzip': _dartGzip,
      'tar': _dartTar,
    };
  }
  final versions = <String, String>{};
  for (final (name, executable) in [
    ('git', bundleGit),
    ('gzip', _gzip),
    ('tar', tarExecutable),
  ]) {
    final result = await Process.run(executable, ['--version']);
    if (result.exitCode != 0) {
      throw SourceBundleException(
        '$executable --version exited ${result.exitCode}: ${result.stderr}',
      );
    }
    // Apple's gzip prints its version on standard error.
    final text = '${result.stdout}'.trim().isEmpty
        ? '${result.stderr}'
        : '${result.stdout}';
    versions[name] = text.trim().split('\n').first.trim();
    if (versions[name]!.isEmpty) {
      throw SourceBundleException('$executable --version printed nothing');
    }
  }
  return versions;
}

/// Writes the tree of [commit] in the git repository [directory] to
/// [bundle], under a top-level directory named for [bundle].
///
/// [bundleGit]'s `git archive` runs cut off from the user's and the
/// system's configuration, with no attributes file, no line-ending
/// conversion and a `tar.umask` of 0022; `gzip -n -9` compresses it with no
/// name or time. The same commit therefore packs to the same bytes with the
/// same git and gzip, whose versions [packingToolVersions] reads. On
/// Windows, `dart:io`'s zlib compresses it at level 9 instead, as
/// [gzipCompress] does.
/// [environment] replaces this process's environment as the one git's
/// isolation starts from.
Future<void> packBundle(
  String directory,
  String commit,
  String bundle, {
  Map<String, String>? environment,
}) async {
  final prefix = _prefix(bundle);
  File(bundle).parent.createSync(recursive: true);
  final tar = '$bundle.tar';
  await runIsolatedGit(
    directory,
    [
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
    ],
    environment: environment,
    executable: bundleGit,
  );
  if (Platform.isWindows) {
    try {
      File(bundle).writeAsBytesSync(
        gzipCompress(File(tar).readAsBytesSync()),
        flush: true,
      );
    } finally {
      File(tar).deleteSync();
    }
    return;
  }
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
///
/// On Windows [unpackTarGz] unpacks it, recording each file's mode, which
/// NTFS cannot hold, for `unpackedFiles` to read. Elsewhere [checkTarGz]
/// holds every member to the rules [unpackTarGz] does, in Dart, before
/// [tarExecutable] unpacks it, so a bundle is refused alike on every host,
/// but for a symbolic link, which tar unpacks there and a build on Windows
/// refuses. [operatingSystem], as `Platform.operatingSystem` spells it, is by
/// default the host's; tests name another.
Future<void> unpackBundle(
  String bundle,
  String destination, {
  String? operatingSystem,
}) async {
  if (FileSystemEntity.typeSync(destination) != FileSystemEntityType.notFound) {
    throw SourceBundleException('$destination already exists');
  }
  Directory(destination).createSync(recursive: true);
  final windows = (operatingSystem ?? Platform.operatingSystem) == 'windows';
  try {
    if (windows) {
      await unpackTarGz(bundle, destination, stripComponents: 1);
      return;
    }
    await checkTarGz(
      bundle,
      stripComponents: 1,
      operatingSystem: operatingSystem,
    );
  } on Exception catch (error) {
    throw SourceBundleException('could not unpack $bundle: $error');
  }
  final result = await Process.run(tarExecutable, [
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

/// The text of [path], relative to the repository root, in [bundle], or null
/// when the bundle holds no such file, a directory at [path] included.
///
/// Every member is held to the rules [unpackBundle] holds it to first, on
/// every host, so a bundle naming [path] twice is refused rather than read
/// at either member. [operatingSystem] is as [unpackBundle] takes it.
///
/// Throws a [SourceBundleException] for a file that is no UTF-8, read by
/// [tarGzFile] or by tar alike, and for a symbolic link at [path], which
/// is not read on any host: Windows refuses the bundle, and elsewhere tar
/// would read the link as an empty file.
Future<String?> bundleFile(
  String bundle,
  String path, {
  String? operatingSystem,
}) async {
  final bytes = await _bundleFileBytes(
    bundle,
    path,
    operatingSystem: operatingSystem,
  );
  if (bytes == null) return null;
  try {
    return utf8.decode(bytes);
  } on FormatException {
    throw SourceBundleException(
      'could not read $path from $bundle: it is no UTF-8',
    );
  }
}

/// The bytes of [path] in [bundle], as [bundleFile] reads them, or null
/// when the bundle holds no such file.
Future<List<int>?> _bundleFileBytes(
  String bundle,
  String path, {
  String? operatingSystem,
}) async {
  final member = '${_prefix(bundle)}/$path';
  final windows = (operatingSystem ?? Platform.operatingSystem) == 'windows';
  final Map<String, TarMemberType> types;
  try {
    if (windows) {
      return await tarGzFile(bundle, path, operatingSystem: operatingSystem);
    }
    types = await checkTarGz(
      bundle,
      stripComponents: 1,
      operatingSystem: operatingSystem,
    );
  } on TarException catch (error) {
    throw SourceBundleException('could not read $path from $bundle: $error');
  }
  // tar -O writes nothing for a link or a directory, and succeeds; tarGzFile
  // reads a file member alone.
  switch (types[path]) {
    case null || TarMemberType.directory:
      return null;
    case TarMemberType.symlink:
      throw SourceBundleException(
        'could not read $path from $bundle: it is a symbolic link',
      );
    case TarMemberType.file:
  }
  final result = await Process.run(tarExecutable, [
    '-xzOf',
    bundle,
    member,
  ], stdoutEncoding: null);
  if (result.exitCode == 0) return result.stdout as List<int>;
  if ('${result.stderr}'.contains('Not found in archive')) return null;
  throw SourceBundleException(
    'tar could not read $member from $bundle: ${result.stderr}',
  );
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

/// The sha256 of the file at [path]: `/usr/bin/shasum`'s on macOS, and
/// elsewhere, as [sha256InDart] decides, [dartFileSha256]'s.
Future<String> fileSha256(String path) async {
  if (sha256InDart()) return dartFileSha256(path);
  final result = await Process.run(shasumExecutable, ['-a', '256', path]);
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
/// [SourceBundleException] naming the first requirement that fails; its
/// message leaves naming [source] to the caller.
Future<String> checkRecordedBundle(
  String directory,
  PinnedSource source,
  Map<String, Object?> recorded,
) async {
  final record = recorded[source.name];
  if (record is! Map<String, Object?>) {
    throw const SourceBundleException('build_info.json records no bundle');
  }
  final file = '$sourcesDirectoryName/${source.bundleName}';
  if (record['commit'] != source.commit || record['file'] != file) {
    throw SourceBundleException(
      'build_info.json records ${record['file']} at ${record['commit']}; '
      'the pin is ${source.commit}',
    );
  }
  final bundle = p.join(directory, source.bundleName);
  if (!File(bundle).existsSync()) {
    throw SourceBundleException('no $bundle');
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
