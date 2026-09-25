/// Runs git against one named directory.
library;

import 'dart:convert';
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
  String toString() =>
      'git ${arguments.join(' ')} (in $directory) exited '
      '$exitCode: ${stderr.trim()}';
}

/// Runs `git` with [arguments] in [directory] and returns its stdout.
///
/// A typedef so tests can answer git commands without a repository.
typedef GitRunner =
    Future<String> Function(String directory, List<String> arguments);

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

/// [parent] without the variables that would point git at another
/// repository.
Map<String, String> gitEnvironment(Map<String, String> parent) => {
  for (final MapEntry(:key, :value) in parent.entries)
    if (!_repositoryLocationVariables.contains(key)) key: value,
};

/// [gitEnvironment] of [parent], further cut off from every configuration
/// and attribute source outside the repository itself: no global or system
/// configuration or attributes, no configuration passed through the
/// environment, and no replacement objects.
Map<String, String> isolatedGitEnvironment(Map<String, String> parent) => {
  for (final MapEntry(:key, :value) in gitEnvironment(parent).entries)
    if (!key.startsWith('GIT_CONFIG') && key != 'GIT_ATTR_SOURCE') key: value,
  'GIT_CONFIG_GLOBAL': '/dev/null',
  'GIT_CONFIG_NOSYSTEM': '1',
  'GIT_ATTR_NOSYSTEM': '1',
  'GIT_NO_REPLACE_OBJECTS': '1',
};

/// The result of one git invocation.
typedef _GitResult = ({int exitCode, String stdout, String stderr});

const _decoder = Utf8Decoder(allowMalformed: true);

Future<_GitResult> _git(
  String directory,
  List<String> arguments,
  Map<String, String> environment, {
  String? input,
}) async {
  final process = await Process.start(
    'git',
    arguments,
    workingDirectory: directory,
    environment: environment,
    includeParentEnvironment: false,
  );
  final stdout = process.stdout.transform(_decoder).join();
  final stderr = process.stderr.transform(_decoder).join();
  if (input != null) process.stdin.write(input);
  await process.stdin.close();
  return (
    exitCode: await process.exitCode,
    stdout: await stdout,
    stderr: await stderr,
  );
}

String _stdout(_GitResult result, String directory, List<String> arguments) {
  if (result.exitCode != 0) {
    throw GitException(directory, arguments, result.exitCode, result.stderr);
  }
  return result.stdout;
}

/// Runs the real `git` with the user's configuration, throwing a
/// [GitException] on a non-zero exit.
Future<String> runGit(String directory, List<String> arguments) async =>
    _stdout(
      await _git(directory, arguments, gitEnvironment(Platform.environment)),
      directory,
      arguments,
    );

/// Runs the real `git` with [isolatedGitEnvironment] of [environment], by
/// default this process's, writing [input] to its standard input; throws a
/// [GitException] on a non-zero exit.
Future<String> runIsolatedGit(
  String directory,
  List<String> arguments, {
  Map<String, String>? environment,
  String? input,
}) async => _stdout(
  await _git(
    directory,
    arguments,
    isolatedGitEnvironment(environment ?? Platform.environment),
    input: input,
  ),
  directory,
  arguments,
);
