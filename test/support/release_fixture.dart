import 'dart:convert';
import 'dart:io';

import 'package:checks/checks.dart';
import 'package:path/path.dart' as p;

import '../../tool/src/build_platform.dart';
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

/// The key under which the fake answers whether the repository's releases
/// are immutable.
const fixtureImmutable = 'api repos/$releaseRepository/immutable-releases';

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

/// The toolchain fields a Linux build records of its linker, its C
/// library and GCC's runtime.
const fixtureLinuxToolchain = {
  'linker': 'GNU ld (GNU Binutils for Ubuntu) 2.46',
  'linkerPackage': 'binutils-aarch64-linux-gnu 2.46-3ubuntu2',
  'linkerPath': '/usr/bin/ld.bfd',
  'linkerResolvedPath': '/usr/bin/aarch64-linux-gnu-ld.bfd',
  'hostLibc': 'glibc 2.43',
  'hostLibcBanner':
      'GNU C Library (Ubuntu GLIBC 2.43-2ubuntu2.4) stable release version '
      '2.43',
  'hostLibcPath': '/lib/aarch64-linux-gnu/libc.so.6',
  'hostLibcDev': 'libc6-dev 2.43-2ubuntu2.4',
  'hostLibcDevPath': '/usr/lib/aarch64-linux-gnu/crti.o',
  'gccRuntime': 'libgcc-15-dev 15.2.0-16ubuntu1',
  'gccRuntimePath': '/usr/lib/gcc/aarch64-linux-gnu/15/crtbeginS.o',
};

/// The `build_info.json` of a build: its [platform], [release], commit and
/// the sha256 of its bundles, and of a Linux build its [toolchain], by
/// default [fixtureLinuxToolchain].
Map<String, Object?> buildInfoJson({
  String platform = 'macos-arm64',
  String? release = 'v1.1.0',
  String commit = fixtureCommit,
  Map<String, String> sources = const {'tree-sitter': 'bb', 'latex': 'b2'},
  Map<String, String> generated = const {'swift': 'cc'},
  String? glibc,
  Map<String, Object?>? toolchain,
}) => {
  'release': release,
  'platform': platform,
  'glibcRequirement': ?glibc,
  'toolchain':
      ?(toolchain ??
      (platform.startsWith('linux-') ? fixtureLinuxToolchain : null)),
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
  String Function(String sha256, String name)? sidecar,
}) {
  final name = 'grammars-$platform.tar.gz';
  final bytes = releaseArchiveBytes(BuildPlatform.parse(platform)!, info);
  final path = p.join(directory, name);
  File(path).writeAsBytesSync(bytes);
  final sha256 = dartSha256(bytes);
  File(
    '$path.sha256',
  ).writeAsStringSync(sidecar?.call(sha256, name) ?? '$sha256  $name\n');
  return sha256;
}

/// The files a release archive of [platform] holds in the tiny fixture,
/// relative to its root, in the order the real packer writes them: sorted
/// by code unit, at the root, with no top-level directory.
List<String> fixtureArchiveFiles(BuildPlatform platform) => [
  'THIRD_PARTY_NOTICES.md',
  'build_info.json',
  'dylibs/ada/${platform.libraryFileName('ada')}',
  platform.runtimeFileName,
  'manifest.json',
  'queries/ada/highlights.scm',
]..sort();

/// A release archive of [platform] laid out as `packArchive` writes one:
/// a ustar stream of files only, at the root, owned by root:wheel, with
/// [info] as its `build_info.json`.
List<int> releaseArchiveBytes(
  BuildPlatform platform,
  Map<String, Object?> info,
) => gzipCompress(
  ustar([
    for (final file in fixtureArchiveFiles(platform))
      (
        path: file,
        bytes: file == 'build_info.json'
            ? utf8.encode(jsonEncode(info))
            : utf8.encode('$file\n'),
        mode: BuildPlatform.isAnyLibrary(file) ? 0x1ed : 0x1a4,
        epoch: 0,
      ),
  ]),
);
