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

/// Requires the repository at [root] to have a clean working tree and to
/// record the `tree-sitter` submodule at [runtimeCommit]; unless [dryRun],
/// also requires [release] to be an annotated tag under `refs/tags/` that
/// points at `HEAD`.
///
/// A branch or any other ref named [release] never stands in for the tag.
/// Throws a [ReleaseException] naming the first requirement that fails.
Future<void> checkReleasePreflight(
  GitRunner git,
  String root,
  String release, {
  required String runtimeCommit,
  required bool dryRun,
}) async {
  final status = (await git(root, ['status', '--porcelain'])).trim();
  if (status.isNotEmpty) {
    throw ReleaseException('a release builds from a clean working tree:\n'
        '$status');
  }
  final gitlink = (await git(root, ['ls-tree', 'HEAD', 'tree-sitter']))
      .trim()
      .split(RegExp(r'\s+'));
  final recorded = gitlink.length < 3 ? 'nothing' : gitlink[2];
  if (recorded != runtimeCommit) {
    throw ReleaseException('HEAD records the tree-sitter submodule at '
        '$recorded, not $runtimeCommit');
  }
  if (dryRun) return;
  final String tagObject;
  try {
    tagObject =
        (await git(root, ['show-ref', '--verify', 'refs/tags/$release']))
            .trim()
            .split(' ')
            .first;
  } on GitException {
    throw ReleaseException('no tag $release; tag the release commit with '
        'git tag -a $release');
  }
  if ((await git(root, ['cat-file', '-t', tagObject])).trim() != 'tag') {
    throw ReleaseException('$release is a lightweight tag; a release tag '
        'is annotated: git tag -a $release');
  }
  final tagged =
      (await git(root, ['rev-parse', '--verify', '$tagObject^{commit}']))
          .trim();
  final head = (await git(root, ['rev-parse', 'HEAD'])).trim();
  if (tagged != head) {
    throw ReleaseException('HEAD is $head, but $release is $tagged');
  }
}
