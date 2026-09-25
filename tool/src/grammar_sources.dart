/// Supplies a pinned grammar's source tree from `grammars/<repo>`, used only
/// as a git object store: its working tree is never read.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import 'git.dart';
import 'grammar_pins.dart';

/// Thrown when a grammar's object store cannot supply its pinned source.
final class GrammarSourceException implements Exception {
  const GrammarSourceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Makes [directory] a git object store whose origin is [url].
///
/// Creates it with `git init` and `git remote add origin` when it does not
/// exist. Throws a [GrammarSourceException] when it exists but is not a git
/// repository, or when its origin is another repository.
Future<void> ensureObjectStore(
  GitRunner git,
  String directory,
  String url,
) async {
  final name = repositoryName(url);
  if (!Directory(directory).existsSync()) {
    Directory(directory).createSync(recursive: true);
    await git(directory, ['init', '--quiet']);
    await git(directory, ['remote', 'add', 'origin', url]);
    return;
  }
  // Without its own .git, git would answer for the enclosing repository.
  if (!FileSystemEntity.isDirectorySync(p.join(directory, '.git'))) {
    throw GrammarSourceException('$name: $directory is not a git repository');
  }
  final origin = (await git(directory, ['remote', 'get-url', 'origin'])).trim();
  if (normalizeRepositoryUrl(origin) != normalizeRepositoryUrl(url)) {
    throw GrammarSourceException('$name: origin of $directory is $origin, '
        'grammars.json says $url');
  }
}

/// Makes sure [directory]'s object store holds [commit], fetching exactly
/// that commit from origin when it does not.
Future<void> ensureCommit(
  GitRunner git,
  String directory,
  String commit,
  String name,
) async {
  if (await _hasCommit(git, directory, commit)) return;
  await git(directory, ['fetch', '--quiet', '--depth', '1', 'origin', commit]);
  if (!await _hasCommit(git, directory, commit)) {
    throw GrammarSourceException('$name: origin did not supply $commit');
  }
}

Future<bool> _hasCommit(GitRunner git, String directory, String commit) async {
  try {
    await git(directory, ['cat-file', '-e', '$commit^{commit}']);
    return true;
  } on GitException {
    return false;
  }
}

/// Extracts the tree of [commit] from [directory]'s object store into
/// [destination], which must not exist yet, and proves every extracted file
/// is its committed blob.
///
/// `git archive` runs with [runIsolatedGit], so no global, system or
/// environment configuration of the user's converts line endings or leaves
/// files out. A conversion or exclusion that the repository itself asks
/// for, through its own `.gitattributes`, `info/attributes` or
/// configuration, still would, so the extracted tree is then compared with
/// `git ls-tree` of [commit]: a missing or extra path, or a file whose
/// bytes hash to anything but its blob, throws a
/// [GrammarSourceException]. Submodule entries carry no files and are
/// skipped.
///
/// [environment] replaces this process's environment as the one git's
/// isolation starts from.
Future<void> extractCommit(
  String directory,
  String commit,
  String destination, {
  Map<String, String>? environment,
}) async {
  if (FileSystemEntity.typeSync(destination) != FileSystemEntityType.notFound) {
    throw GrammarSourceException('$destination already exists');
  }
  Future<String> git(List<String> arguments, {String? input}) =>
      runIsolatedGit(directory, arguments,
          environment: environment, input: input);
  Directory(destination).createSync(recursive: true);
  final archive = '$destination.tar';
  await git([
    '-c',
    'core.attributesFile=/dev/null',
    '-c',
    'core.autocrlf=false',
    '-c',
    'core.eol=lf',
    'archive',
    '--format=tar',
    '--output=${p.absolute(archive)}',
    commit,
  ]);
  final tar = await Process.run('tar', ['-xf', archive, '-C', destination]);
  File(archive).deleteSync();
  if (tar.exitCode != 0) {
    throw GrammarSourceException(
        'tar could not extract $commit into $destination: ${tar.stderr}');
  }
  final problems = await _extractionProblems(git, commit, destination);
  if (problems.isNotEmpty) {
    throw GrammarSourceException([
      '$destination differs from $commit in ${p.basename(directory)}:',
      ...problems,
    ].join('\n    '));
  }
}

/// One blob of a commit's tree, as `git ls-tree -r` lists it.
typedef _TreeBlob = ({String mode, String object});

/// Runs git in the object store being extracted from.
typedef _Git = Future<String> Function(List<String> arguments, {String? input});

/// Every way [destination] differs from the tree of [commit].
Future<List<String>> _extractionProblems(
  _Git git,
  String commit,
  String destination,
) async {
  final committed = <String, _TreeBlob>{};
  final listing = await git(['ls-tree', '-r', '-z', '--full-tree', commit]);
  for (final record in listing.split('\x00').where((r) => r.isNotEmpty)) {
    final tab = record.indexOf('\t');
    final [mode, type, object] = record.substring(0, tab).split(' ');
    final path = record.substring(tab + 1);
    if (type == 'blob') committed[path] = (mode: mode, object: object);
  }
  final extracted = {
    for (final entity
        in Directory(destination).listSync(recursive: true, followLinks: false))
      if (entity is! Directory)
        p.posix.joinAll(p.split(p.relative(entity.path, from: destination))):
            entity,
  };
  final problems = [
    for (final path in committed.keys.where((k) => !extracted.containsKey(k)))
      '$path: committed but not extracted',
    for (final path in extracted.keys.where((k) => !committed.containsKey(k)))
      '$path: extracted but not committed',
  ];
  final files = <String>[];
  for (final MapEntry(key: path, value: blob) in committed.entries) {
    final entity = extracted[path];
    if (entity == null) continue;
    if (blob.mode == '120000') {
      final target = entity is Link ? entity.targetSync() : null;
      if (target != await git(['cat-file', 'blob', blob.object])) {
        problems.add('$path: not the committed symbolic link');
      }
    } else if (entity is! File) {
      problems.add('$path: not a regular file');
    } else if (path.contains('\n')) {
      problems.add('$path: a path with a newline cannot be checked');
    } else {
      files.add(path);
    }
  }
  final hashes = await _hashObjects(
      git, [for (final path in files) p.join(destination, path)]);
  for (final (index, path) in files.indexed) {
    if (hashes[index] != committed[path]!.object) {
      problems.add('$path: extracted bytes are not the committed blob');
    }
  }
  return problems;
}

/// The blob ids of [paths], hashed exactly as they are on disk.
Future<List<String>> _hashObjects(_Git git, List<String> paths) async {
  if (paths.isEmpty) return const [];
  final hashes = (await git(
    ['hash-object', '--no-filters', '--stdin-paths'],
    input: '${paths.join('\n')}\n',
  ))
      .split('\n')
      .where((line) => line.isNotEmpty)
      .toList();
  if (hashes.length != paths.length) {
    throw GrammarSourceException('git hash-object answered '
        '${hashes.length} of ${paths.length} paths');
  }
  return hashes;
}
