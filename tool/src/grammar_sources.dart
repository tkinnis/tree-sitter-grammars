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
/// [destination], which must not exist yet.
///
/// Line endings are never converted, whatever the user's git configuration
/// says, so the extracted bytes are the committed bytes.
Future<void> extractCommit(
  GitRunner git,
  String directory,
  String commit,
  String destination,
) async {
  if (FileSystemEntity.typeSync(destination) != FileSystemEntityType.notFound) {
    throw GrammarSourceException('$destination already exists');
  }
  Directory(destination).createSync(recursive: true);
  final archive = '$destination.tar';
  await git(directory, [
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
}
