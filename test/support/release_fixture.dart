import 'dart:convert';
import 'dart:io';

import 'package:checks/checks.dart';
import 'package:path/path.dart' as p;

import '../../tool/src/github.dart';
import '../../tool/src/tar.dart';

const fixtureTagObject = '1111111111111111111111111111111111111111';
const fixtureCommit = '2222222222222222222222222222222222222222';
const fixtureOtherCommit = '3333333333333333333333333333333333333333';
const fixtureReleaseId = 77;

const fixtureRef = 'api repos/$releaseRepository/git/ref/tags/v1.1.0';
const fixtureTag = 'api repos/$releaseRepository/git/tags/$fixtureTagObject';
const fixtureListing = 'api repos/$releaseRepository/releases?per_page=100';
const fixtureById = 'api repos/$releaseRepository/releases/$fixtureReleaseId';

/// The key under which the fake answers the download of asset [id].
String fixtureAsset(int id) =>
    'api repos/$releaseRepository/releases/assets/$id';

/// The key under which the fake answers the request that publishes the
/// fixture release.
const fixturePatch =
    'PATCH repos/$releaseRepository/releases/$fixtureReleaseId';

final _assetIds = <String, int>{};

/// The id of the asset [name] in the fixture release: one per name.
int fixtureAssetId(String name) =>
    _assetIds.putIfAbsent(name, () => 1000 + _assetIds.length);

/// A `gh` result.
ProcessResult ghResult(
  int exitCode, {
  Object stdout = '',
  String stderr = '',
}) => ProcessResult(0, exitCode, stdout, stderr);

/// The tag resolutions of a pushed annotated tag [fixtureTagObject] naming
/// [fixtureCommit].
final fixturePushed = {
  fixtureRef: ghResult(0, stdout: 'tag $fixtureTagObject\n'),
  fixtureTag: ghResult(0, stdout: 'commit $fixtureCommit\n'),
};

/// Answers `gh` by its first two arguments from [answers], a result or a
/// list of results given in turn (the last one repeating), recording every
/// call in [calls].
ProcessRunner fakeGh(Map<String, Object> answers, List<List<String>> calls) {
  final given = <String, int>{};
  return (executable, arguments) async {
    check(executable).equals('gh');
    calls.add(arguments);
    final key = arguments.contains('PATCH')
        ? 'PATCH ${arguments[1]}'
        : arguments.take(2).join(' ');
    if (key == fixtureListing) {
      // The listing is paginated and slurped into one array of pages.
      check(arguments).containsEqualInOrder(['--paginate', '--slurp']);
    }
    return switch (answers[key]) {
      final ProcessResult result => result,
      final List<ProcessResult> results =>
        results[(given[key] = (given[key] ?? -1) + 1).clamp(
          0,
          results.length - 1,
        )],
      _ => throw StateError('unexpected gh ${arguments.join(' ')}'),
    };
  };
}

/// A release asset in the REST API's spelling.
///
/// A [sha256] of null is a digest GitHub has not computed yet, which it
/// spells `"digest": null`.
Map<String, Object?> assetJson(
  String name,
  String? sha256, {
  String? state = 'uploaded',
}) => {
  'id': fixtureAssetId(name),
  'name': name,
  'state': state,
  'digest': sha256 == null ? null : 'sha256:$sha256',
};

/// A release in the REST API's spelling.
Map<String, Object?> releaseJson({
  String tag = 'v1.1.0',
  bool draft = true,
  bool immutable = false,
  String target = fixtureCommit,
  int id = fixtureReleaseId,
  String body = 'notes',
  List<Map<String, Object?>> assets = const [],
}) => {
  'id': id,
  'tag_name': tag,
  'draft': draft,
  'immutable': immutable,
  'target_commitish': target,
  'body': body,
  'assets': assets,
};

/// A paginated listing, `gh api --paginate --slurp` style, of [releases],
/// one to a page.
ProcessResult listing(List<Map<String, Object?>> releases) => ghResult(
  0,
  stdout: jsonEncode([
    for (final release in releases) [release],
  ]),
);

/// The `build_info.json` of a build: its [platform], [release], commit and
/// the sha256 of its bundles.
Map<String, Object?> buildInfoJson({
  String platform = 'macos-arm64',
  String? release = 'v1.1.0',
  String commit = fixtureCommit,
  Map<String, String> sources = const {'tree-sitter': 'bb', 'latex': 'b2'},
  Map<String, String> generated = const {'swift': 'cc'},
  String? glibc,
}) => {
  'release': release,
  'platform': platform,
  'glibcRequirement': ?glibc,
  'repository': {'url': 'u', 'commit': commit, 'dirty': false},
  'sources': {
    for (final MapEntry(:key, :value) in sources.entries)
      key: {'file': 'sources/$key-0.tar.gz', 'sha256': value},
  },
  'generated': {
    for (final MapEntry(:key, :value) in generated.entries)
      key: {'file': 'sources/$key-gen.tar.gz', 'sha256': value},
  },
};

/// Writes `grammars-<platform>.tar.gz`, holding [info] as its
/// `build_info.json`, and its `.sha256` into [directory]; returns the
/// archive's sha256.
String writeArchive(
  String directory,
  String platform,
  Map<String, Object?> info, {
  String? sidecar,
}) {
  final name = 'grammars-$platform.tar.gz';
  final bytes = gzipCompress(
    ustar([
      (
        path: 'grammars/build_info.json',
        bytes: utf8.encode(jsonEncode(info)),
        mode: 420,
        epoch: 0,
      ),
    ]),
  );
  final path = p.join(directory, name);
  File(path).writeAsBytesSync(bytes);
  final sha256 = dartSha256(bytes);
  File('$path.sha256').writeAsStringSync(sidecar ?? '$sha256  $name\n');
  return sha256;
}
