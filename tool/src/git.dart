/// Runs git against one named directory.
library;

import 'dart:io';

/// Thrown when a git command exits non-zero.
final class GitException implements Exception {
  const GitException(
    this.directory,
    this.arguments,
    this.exitCode,
    this.stderr,
  );

  final String directory;
  final List<String> arguments;
  final int exitCode;
  final String stderr;

  @override
  String toString() => 'git ${arguments.join(' ')} (in $directory) exited '
      '$exitCode: ${stderr.trim()}';
}

/// Runs `git` with [arguments] in [directory] and returns its stdout.
///
/// A typedef so tests can answer git commands without a repository.
typedef GitRunner = Future<String> Function(
  String directory,
  List<String> arguments,
);

/// Variables that would point git at a repository other than the one in
/// the working directory, for example when a hook runs this tool.
const _repositoryLocationVariables = {
  'GIT_DIR',
  'GIT_WORK_TREE',
  'GIT_INDEX_FILE',
  'GIT_OBJECT_DIRECTORY',
  'GIT_ALTERNATE_OBJECT_DIRECTORIES',
  'GIT_COMMON_DIR',
};

Map<String, String> get _environment => {
      for (final MapEntry(:key, :value) in Platform.environment.entries)
        if (!_repositoryLocationVariables.contains(key)) key: value,
    };

/// Runs the real `git`, throwing a [GitException] on a non-zero exit.
Future<String> runGit(String directory, List<String> arguments) async {
  final result = await Process.run(
    'git',
    arguments,
    workingDirectory: directory,
    environment: _environment,
    includeParentEnvironment: false,
  );
  if (result.exitCode != 0) {
    throw GitException(
      directory,
      arguments,
      result.exitCode,
      result.stderr as String,
    );
  }
  return result.stdout as String;
}

/// Whether `git` with [arguments] in [directory] exits zero.
Future<bool> gitSucceeds(String directory, List<String> arguments) async {
  final result = await Process.run(
    'git',
    arguments,
    workingDirectory: directory,
    environment: _environment,
    includeParentEnvironment: false,
  );
  return result.exitCode == 0;
}
