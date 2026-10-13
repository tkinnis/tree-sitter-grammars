/// What publishing, attaching and finalizing a release share: running the
/// GitHub CLI, checking the tag on GitHub, and reading releases.
library;

import 'dart:convert';
import 'dart:io';

import 'build_platform.dart';

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
    final answer = outputText(result.stdout).trim();
    return switch (answer.split(' ')) {
      [final type, final sha] => (type, sha),
      _ => throw PublishException(
        '$when, GitHub answered "$answer" for $tag, not "<type> <sha>"',
      ),
    };
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

/// One asset of a GitHub release.
///
/// [state] is `uploaded` once the asset is complete; [digest] is null until
/// GitHub has computed it.
typedef ReleaseAsset = ({int id, String name, String? digest, String? state});

/// A GitHub release as the REST API describes it.
final class GitHubRelease {
  const GitHubRelease({
    required this.id,
    required this.tagName,
    required this.draft,
    required this.immutable,
    required this.target,
    required this.body,
    required this.assets,
  });

  /// Reads the release object [json] of the REST API.
  factory GitHubRelease.fromJson(Map<String, Object?> json) => GitHubRelease(
    id: switch (json['id']) {
      final int id => id,
      _ => throw const PublishException('GitHub answered a release with no id'),
    },
    tagName: '${json['tag_name']}',
    draft: json['draft'] == true,
    immutable: json['immutable'] == true,
    target: '${json['target_commitish']}',
    body: '${json['body'] ?? ''}',
    assets: [
      for (final asset in json['assets'] as List? ?? const [])
        (
          id: (asset as Map<String, Object?>)['id'] as int? ?? 0,
          name: '${asset['name']}',
          digest: asset['digest'] as String?,
          state: asset['state'] as String?,
        ),
    ],
  );

  final int id;
  final String tagName;

  /// Whether the release is a draft, not yet published.
  final bool draft;

  /// Whether GitHub reports the release as immutable: published, and never
  /// to gain or change an asset.
  final bool immutable;

  /// The release's `target_commitish`: a branch name or a commit.
  final String target;
  final String body;
  final List<ReleaseAsset> assets;

  /// The asset named [name], or null when the release has none.
  ReleaseAsset? asset(String name) =>
      assets.where((asset) => asset.name == name).firstOrNull;
}

/// Decodes the JSON [result] of a `gh api` call, or throws a
/// [PublishException] saying that [what] failed.
Object? _decoded(ProcessResult result, String what) {
  if (result.exitCode != 0) {
    throw PublishException('$what failed: ${errorText(result)}');
  }
  try {
    return jsonDecode(outputText(result.stdout));
  } on FormatException catch (error) {
    throw PublishException('$what answered something other than JSON: $error');
  }
}

/// Every release of [releaseRepository], drafts included, whose tag is
/// [tag].
///
/// The listing is paginated: `releases/tags/<tag>` finds no draft, so a
/// draft is found only by reading every page. More than one release can
/// carry a tag while one of them is a draft.
Future<List<GitHubRelease>> releasesOfTag(GitHubCli gh, String tag) async {
  final pages = _decoded(
    await gh([
      'api',
      'repos/$releaseRepository/releases?per_page=100',
      '--paginate',
      '--slurp',
    ]),
    'listing the releases of $releaseRepository',
  );
  if (pages is! List) {
    throw const PublishException('GitHub listed the releases as a non-list');
  }
  return [
    for (final page in pages)
      for (final release in page is List ? page : [page])
        if (release is Map<String, Object?> && release['tag_name'] == tag)
          GitHubRelease.fromJson(release),
  ];
}

/// The release with [id], read afresh.
Future<GitHubRelease> readRelease(GitHubCli gh, int id) async {
  final release = _decoded(
    await gh(['api', 'repos/$releaseRepository/releases/$id']),
    'reading release $id',
  );
  if (release is! Map<String, Object?>) {
    throw PublishException('GitHub answered release $id as a non-object');
  }
  return GitHubRelease.fromJson(release);
}

/// The bytes of the asset with [assetId] of [releaseRepository], which a
/// draft's assets are read through, since `releases/tags/<tag>` finds no
/// draft.
Future<List<int>> downloadAsset(GitHubCli gh, int assetId) async {
  final result = await gh([
    'api',
    'repos/$releaseRepository/releases/assets/$assetId',
    '-H',
    binaryAcceptHeader,
  ]);
  if (result.exitCode != 0) {
    throw PublishException(
      'downloading asset $assetId failed: ${errorText(result)}',
    );
  }
  return outputBytes(result.stdout);
}

/// The platform [id] names.
///
/// Throws a [PublishException] when [id] is absent or names no platform a
/// build targets, so a garbled `platform` is never read as any other.
BuildPlatform requirePlatform(Object? id) =>
    BuildPlatform.parse(id) ??
    (throw PublishException(
      'build_info.json records the platform $id; a platform is one of '
      '${BuildPlatform.values.map((platform) => platform.id).join(', ')}',
    ));
