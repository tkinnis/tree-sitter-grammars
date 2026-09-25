/// Checks that the repository is in a state a release builds from, and
/// names the archive a build packs.
library;

import 'git.dart';

/// Thrown when the repository is not in a state a release builds from.
final class ReleaseException implements Exception {
  const ReleaseException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The release asset a build packs for `macos-arm64`.
const releaseArchiveName = 'grammars-macos-arm64.tar.gz';

/// The archive a `--dry-run` build packs: the bytes a tagged build of the
/// same commit packs, under a name no release asset has, so it is never
/// mistaken for or uploaded as the release.
const dryRunArchiveName = 'grammars-macos-arm64.dry-run.tar.gz';

/// Requires the repository at [root] to have a clean working tree and,
/// unless [dryRun], [release] to be an annotated tag under `refs/tags/`
/// that points at `HEAD`; returns `HEAD`'s commit, the one the release
/// builds.
///
/// A branch or any other ref named [release] never stands in for the tag.
/// Throws a [ReleaseException] naming the first requirement that fails.
Future<String> checkReleasePreflight(
  GitRunner git,
  String root,
  String release, {
  required bool dryRun,
}) async {
  await _requireClean(git, root, 'a release builds from a clean working tree');
  final head = (await git(root, ['rev-parse', 'HEAD'])).trim();
  if (dryRun) return head;
  final String tagObject;
  try {
    tagObject = (await git(root, [
      'show-ref',
      '--verify',
      'refs/tags/$release',
    ])).trim().split(' ').first;
  } on GitException {
    throw ReleaseException(
      'no tag $release; tag the release commit with '
      'git tag -a $release',
    );
  }
  if ((await git(root, ['cat-file', '-t', tagObject])).trim() != 'tag') {
    throw ReleaseException(
      '$release is a lightweight tag; a release tag '
      'is annotated: git tag -a $release',
    );
  }
  final tagged = (await git(root, [
    'rev-parse',
    '--verify',
    '$tagObject^{commit}',
  ])).trim();
  if (tagged != head) {
    throw ReleaseException('HEAD is $head, but $release is $tagged');
  }
  return head;
}

/// Requires [commit] in the repository at [root] to record the
/// `tree-sitter` submodule at [runtimeCommit].
///
/// Throws a [ReleaseException] when it records another commit or none.
Future<void> checkRecordedRuntime(
  GitRunner git,
  String root,
  String commit,
  String runtimeCommit,
) async {
  final gitlink = (await git(root, [
    'ls-tree',
    commit,
    'tree-sitter',
  ])).trim().split(RegExp(r'\s+'));
  final recorded = gitlink.length < 3 ? 'nothing' : gitlink[2];
  if (recorded != runtimeCommit) {
    throw ReleaseException(
      '$commit records the tree-sitter submodule at '
      '$recorded, not $runtimeCommit',
    );
  }
}

/// Requires the repository at [root] still to be at [commit], the commit a
/// release build began from, with a clean working tree.
///
/// A release build reads this repository's own files from [commit] itself,
/// so a change to the working tree cannot reach what it packs. The tools
/// that check the build run from the working tree, so a release is packed
/// only when nothing changed under them either. Throws a
/// [ReleaseException] naming what changed.
Future<void> checkUnchangedSince(
  GitRunner git,
  String root,
  String commit,
) async {
  final head = (await git(root, ['rev-parse', 'HEAD'])).trim();
  if (head != commit) {
    throw ReleaseException(
      'HEAD moved from $commit to $head during the build; '
      'nothing is packed',
    );
  }
  await _requireClean(
    git,
    root,
    'the working tree changed during the build; nothing is packed',
  );
}

Future<void> _requireClean(GitRunner git, String root, String message) async {
  final status = (await git(root, ['status', '--porcelain'])).trim();
  if (status.isNotEmpty) throw ReleaseException('$message:\n$status');
}
