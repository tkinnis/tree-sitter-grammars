/// What publishing, attaching and finalizing a release share: running the
/// GitHub CLI, checking the tag on GitHub, and reading releases.
library;

import 'dart:convert';
import 'dart:io';

/// The GitHub repository releases are published to.
const releaseRepository = 'tkinnis/tree-sitter-grammars';

/// Runs [executable] with [arguments] and returns its result.
///
/// A typedef so tests can answer `gh` without the network.
typedef ProcessRunner =
    Future<ProcessResult> Function(String executable, List<String> arguments);

/// The header that makes the GitHub API answer with an asset's bytes.
const binaryAcceptHeader = 'Accept: application/octet-stream';

/// Runs [executable] with [arguments]; the output is bytes when
/// [arguments] ask for [binaryAcceptHeader], text otherwise.
Future<ProcessResult> runProcess(String executable, List<String> arguments) =>
    Process.run(
      executable,
      arguments,
      stdoutEncoding: arguments.contains(binaryAcceptHeader)
          ? null
          : systemEncoding,
    );

/// Thrown when a release cannot be, or was not, published as packed.
final class PublishException implements Exception {
  const PublishException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Runs `gh` with arguments.
typedef GitHubCli = Future<ProcessResult> Function(List<String> arguments);

/// [run] as a function of `gh`'s arguments, turning a missing `gh` into a
/// [PublishException].
GitHubCli githubCli(ProcessRunner run) => (arguments) async {
  try {
    return await run('gh', arguments);
  } on ProcessException catch (error) {
    throw PublishException('gh could not run: ${error.message}');
  }
};

/// [output], a process's stdout, as text.
String outputText(Object? output) =>
    output is List<int> ? utf8.decode(output) : '$output';

/// [output], a process's stdout, as bytes.
List<int> outputBytes(Object? output) =>
    output is List<int> ? output : utf8.encode('$output');

/// [result]'s stderr, trimmed.
String errorText(ProcessResult result) => '${result.stderr}'.trim();

/// Requires [tag] on GitHub to be the annotated tag object [tagObject],
/// which names [commit].
///
/// [when] begins the message of the [PublishException] thrown when it is
/// not, for example `before publishing`.
Future<void> requirePushedTag(
  GitHubCli gh, {
  required String tag,
  required String tagObject,
  required String commit,
  required String when,
}) async {
  Future<(String, String)> object(String path) async {
    final result = await gh([
      'api',
      'repos/$releaseRepository/$path',
      '--jq',
      '.object.type + " " + .object.sha',
    ]);
    if (result.exitCode != 0) {
      throw PublishException(
        '$when, GitHub could not resolve $tag: ${errorText(result)}; '
        'push it with git push origin $tag',
      );
    }
    final [type, sha] = outputText(result.stdout).trim().split(' ');
    return (type, sha);
  }

  final (type, sha) = await object('git/ref/tags/$tag');
  if (type != 'tag') {
    throw PublishException(
      '$when, $tag on GitHub is a lightweight tag of $sha; a release tag '
      'is annotated',
    );
  }
  if (sha != tagObject) {
    throw PublishException(
      '$when, $tag on GitHub is the tag object $sha, not the local tag '
      '$tagObject the build checked',
    );
  }
  final (targetType, target) = await object('git/tags/$sha');
  if (targetType != 'commit' || target != commit) {
    throw PublishException(
      '$when, $tag on GitHub names $targetType $target, not the built '
      'commit $commit',
    );
  }
}
