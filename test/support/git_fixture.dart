/// Real git repositories in a temporary directory, for tests that exercise
/// the tools' git commands end to end.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// The environment fixture commands run with: no user or system
/// configuration, so a signing or hook setting of the user's never runs, and
/// a fixed author and date, so every commit is reproducible.
const fixtureGitEnvironment = {
  'GIT_CONFIG_GLOBAL': '/dev/null',
  'GIT_CONFIG_NOSYSTEM': '1',
  'GIT_AUTHOR_NAME': 'Fixture',
  'GIT_AUTHOR_EMAIL': 'fixture@example.com',
  'GIT_AUTHOR_DATE': '2026-01-01T00:00:00Z',
  'GIT_COMMITTER_NAME': 'Fixture',
  'GIT_COMMITTER_EMAIL': 'fixture@example.com',
  'GIT_COMMITTER_DATE': '2026-01-01T00:00:00Z',
};

/// Runs git in [directory] with [fixtureGitEnvironment] and returns its
/// trimmed stdout; throws a [StateError] on a non-zero exit.
Future<String> fixtureGit(String directory, List<String> arguments) async {
  final result = await Process.run(
    'git',
    arguments,
    workingDirectory: directory,
    environment: {
      'PATH': Platform.environment['PATH'] ?? '/usr/bin:/bin',
      ...fixtureGitEnvironment,
    },
    includeParentEnvironment: false,
  );
  if (result.exitCode != 0) {
    throw StateError(
      'git ${arguments.join(' ')} in $directory: '
      '${result.stderr}',
    );
  }
  return (result.stdout as String).trim();
}

/// A git repository at [path] with a working tree.
final class FixtureRepository {
  FixtureRepository._(this.path);

  /// Creates an empty repository at [path], whose default branch is `main`.
  static Future<FixtureRepository> create(String path) async {
    Directory(path).createSync(recursive: true);
    await fixtureGit(path, ['init', '--quiet', '--initial-branch=main']);
    return FixtureRepository._(path);
  }

  final String path;

  /// Writes [files], each a path relative to the repository mapped to its
  /// bytes, and commits every change; returns the new commit.
  Future<String> commit(
    Map<String, List<int>> files, {
    String message = 'change',
  }) async {
    for (final MapEntry(:key, :value) in files.entries) {
      final file = File(p.join(path, key));
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(value);
    }
    await fixtureGit(path, ['add', '--all']);
    await fixtureGit(path, [
      'commit',
      '--quiet',
      '--allow-empty',
      '-m',
      message,
    ]);
    return fixtureGit(path, ['rev-parse', 'HEAD']);
  }

  /// Runs git in this repository.
  Future<String> git(List<String> arguments) => fixtureGit(path, arguments);
}

/// [text] as UTF-8 bytes.
List<int> bytes(String text) => utf8.encode(text);
