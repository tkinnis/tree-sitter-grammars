import 'dart:convert';
import 'dart:io';

import 'package:checks/checks.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../tool/src/build_platform.dart';
import '../tool/src/files_digest.dart';
import '../tool/src/grammar_sources.dart';
import '../tool/src/recorded_build.dart';
import '../tool/src/source_bundles.dart';
import '../tool/src/tar.dart';
import '../tool/src/toolchain.dart';
import 'support/git_fixture.dart';
import 'support/raw_tar.dart';

const _cliSha256 =
    '70f7573b2b2e5371a5b58cc5227d2ad981fd5374596b9874e770af486060774e';

/// The commit of this repository a build of the release reads.
const _commit = '77ac13625d220bcf955cb12f697e438238c774e0';

/// A toolchain pinning the runtime at [commit], with no files digest.
Toolchain _toolchain(String commit) => Toolchain.parse(
  jsonEncode({
    'treeSitter': {'tag': 'v0.27.0', 'commit': commit, 'filesSha256': '0' * 64},
    'treeSitterCli': {
      'version': '0.27.0',
      'asset': 'tree-sitter-macos-arm64.gz',
      'sha256': _cliSha256,
    },
    'macos': {'arch': 'arm64', 'deploymentTarget': '13.0'},
  }),
);

void main() {
  late Directory temporary;
  late FixtureRepository upstream;
  late String first;
  late String second;

  setUp(() async {
    temporary = Directory.systemTemp.createTempSync('bundles_test');
    upstream = await FixtureRepository.create(
      p.join(temporary.path, 'tree-sitter-x'),
    );
    first = await upstream.commit({
      'src/parser.c': bytes('int parse(void) { return 0; }\n'),
      'bin/run': bytes('#!/bin/sh\n'),
    });
    second = await upstream.commit({
      'src/parser.c': bytes('int parse(void) { return 1; }\n'),
    });
  });

  tearDown(() => temporary.deleteSync(recursive: true));

  String path(String relative) => p.join(temporary.path, relative);

  PinnedSource source(String commit) => PinnedSource(
    name: 'tree-sitter-x',
    url: 'https://github.com/example/tree-sitter-x',
    commit: commit,
    filesSha256: '0' * 64,
  );

  Future<String> pack(String commit, String directory) async {
    Directory(directory).createSync(recursive: true);
    final bundle = p.join(directory, source(commit).bundleName);
    await packBundle(upstream.path, commit, bundle);
    return bundle;
  }

  test('packing one commit twice writes the same bytes', () async {
    final a = await pack(first, path('a'));
    final b = await pack(first, path('b'));

    check(File(a).readAsBytesSync()).deepEquals(File(b).readAsBytesSync());
  });

  test('a git earlier on PATH never writes a bundle', () async {
    final fake = File(path('fake/git'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('#!/bin/sh\nexit 7\n');
    await Process.run('/bin/chmod', ['755', fake.path]);
    final bundle = path('bundles/${source(first).bundleName}');
    Directory(path('bundles')).createSync();

    await packBundle(
      upstream.path,
      first,
      bundle,
      environment: {
        ...Platform.environment,
        'PATH': '${fake.parent.path}:${Platform.environment['PATH']}',
      },
    );

    check(await bundleCommit(bundle)).equals(first);
    // Windows has no git of fixed path: bundleGit is the git.exe on PATH.
  }, testOn: '!windows');

  test('the packing tools report their versions', () async {
    final versions = await packingToolVersions();

    check(versions.keys).unorderedEquals(['git', 'gzip', 'tar']);
    check(versions['git']!).startsWith('git version ');
    if (Platform.isWindows) {
      check(versions['gzip']!).startsWith('dart:io GZipCodec level 9, Dart ');
      check(versions['tar']!).equals('tool/src/tar.dart ustar');
    } else {
      check(versions['gzip']!).contains('gzip');
      check(versions['tar']!).contains('tar');
    }
  });

  test('a bundle unpacks to the commit\'s tree and names its commit', () async {
    final bundle = await pack(first, path('bundles'));

    await unpackBundle(bundle, path('tree'));

    check(
      File(path('tree/src/parser.c')).readAsStringSync(),
    ).equals('int parse(void) { return 0; }\n');
    check(File(path('tree/bin/run')).existsSync()).isTrue();
    check(await bundleCommit(bundle)).equals(first);
  });

  group('a bundle is checked on every host before tar reads it', () {
    // On macOS and Linux, unpackBundle and bundleFile ran /usr/bin/tar on
    // a bundle with none of the refusals unpackTarGz makes on Windows.
    // Each now runs checkTarGz over the bundle first, in Dart, as here on
    // any host; the tar named here does not exist, so a bundle that
    // reached it would throw a ProcessException, not the refusal.
    late String tar;
    setUp(() {
      tar = tarExecutable;
      tarExecutable = path('no-such-tar');
    });
    tearDown(() => tarExecutable = tar);

    /// A bundle of [members], as rawMembers writes them.
    String bundleOf(List<String> members) {
      final bundle = path('bundle.tar.gz');
      File(bundle).writeAsBytesSync(gzipCompress(rawMembers(members)));
      return bundle;
    }

    for (final (problem, members, message) in [
      (
        'one file twice',
        ['top/', 'top/a.c', 'top/a.c'],
        'top/a.c: an earlier member makes "a.c" a file',
      ),
      (
        // tar strips ./top/a.c of one segment to top/a.c, no duplicate, as
        // the stripped segment is "."; top/./a.c is a.c.
        'one file twice, once as "top/./a.c"',
        ['top/a.c', 'top/./a.c'],
        'top/./a.c: an earlier member makes "a.c" a file',
      ),
      (
        'two files differing only in case',
        ['top/README', 'top/readme'],
        'top/readme: "readme" names the same file as "README" on Windows',
      ),
      (
        'a name Windows cannot give a file',
        ['top/aux.c'],
        'top/aux.c: "aux.c" names the Windows device AUX',
      ),
      (
        'a member leading out of the archive',
        ['top/../../evil'],
        'top/../../evil leads out of the archive',
      ),
    ]) {
      // Reddened by dropping unpackBundle's checkTarGz before tar.
      test('unpackBundle refuses $problem', () async {
        final bundle = bundleOf(members);

        await check(
          unpackBundle(bundle, path('tree'), operatingSystem: 'macos'),
        ).throws<SourceBundleException>(
          (it) => it
              .has((e) => e.message, 'message')
              .startsWith('could not unpack $bundle: $bundle: $message'),
        );
      });
    }

    /// A bundle of the file top/a.c and the symbolic link top/link to it.
    String linkedBundle() {
      final bundle = path('bundle.tar.gz');
      File(bundle).writeAsBytesSync(
        gzipCompress([
          ...rawHeader('top/a.c', '0', 0),
          ...rawLink('top/link', 'a.c'),
          ...List.filled(1024, 0),
        ]),
      );
      return bundle;
    }

    test('on Windows, unpackBundle and bundleFile refuse a symbolic '
        'link', () async {
      // Mutation: allow a symbolic link whatever operatingSystem names;
      // this reddens.
      final bundle = linkedBundle();

      await check(
        unpackBundle(bundle, path('tree'), operatingSystem: 'windows'),
      ).throws<SourceBundleException>(
        (it) => it
            .has((e) => e.message, 'message')
            .contains('top/link is a symbolic link'),
      );
      await check(
        bundleFile(bundle, 'a.c', operatingSystem: 'windows'),
      ).throws<SourceBundleException>(
        (it) => it
            .has((e) => e.message, 'message')
            .contains('top/link is a symbolic link'),
      );
    });

    for (final operatingSystem in ['macos', 'linux']) {
      test('on $operatingSystem, a symbolic link passes the check and '
          'reaches tar', () async {
        // A build on macOS or Linux keeps a committed link, as
        // grammar_sources_test's "extractCommit checks a committed
        // symbolic link by its target" does there. Mutation: refuse a
        // symbolic link whatever operatingSystem names; this reddens.
        final bundle = linkedBundle();

        await check(
          unpackBundle(bundle, path('tree'), operatingSystem: operatingSystem),
        ).throws<ProcessException>();
        await check(
          bundleFile(bundle, 'a.c', operatingSystem: operatingSystem),
        ).throws<ProcessException>();
      });
    }

    test('bundleFile refuses one file twice', () async {
      // Reddened by dropping bundleFile's checkTarGz before tar.
      final bundle = bundleOf(['top/a.c', 'top/a.c']);

      await check(
        bundleFile(bundle, 'a.c', operatingSystem: 'macos'),
      ).throws<SourceBundleException>(
        (it) => it
            .has((e) => e.message, 'message')
            .equals(
              'could not read a.c from $bundle: $bundle: top/a.c: an '
              'earlier member makes "a.c" a file',
            ),
      );
    });

    test('the control: a whole bundle passes the check and reaches '
        'tar', () async {
      final bundle = await pack(first, path('bundles'));

      await check(
        unpackBundle(bundle, path('tree'), operatingSystem: 'macos'),
      ).throws<ProcessException>();
      await check(
        bundleFile(bundle, 'src/parser.c', operatingSystem: 'macos'),
      ).throws<ProcessException>();
    });
  });

  group('checkRecordedBundle', () {
    late String bundle;
    late Map<String, Object?> recorded;

    setUp(() async {
      bundle = await pack(first, path('bundles'));
      recorded = {
        'tree-sitter-x': bundleRecord(source(first), await fileSha256(bundle)),
      };
    });

    test('accepts the recorded bundle and answers its sha256', () async {
      check(
        await checkRecordedBundle(path('bundles'), source(first), recorded),
      ).equals(await fileSha256(bundle));
    });

    test('refuses a bundle whose sha256 is not the recorded one', () async {
      File(bundle).writeAsBytesSync([...File(bundle).readAsBytesSync(), 0]);

      await check(
        checkRecordedBundle(path('bundles'), source(first), recorded),
      ).throws<SourceBundleException>(
        (it) => it.has((e) => e.message, 'message').contains('sha256'),
      );
    });

    test('refuses a record of another commit than the pin', () async {
      await check(
        checkRecordedBundle(path('bundles'), source(second), recorded),
      ).throws<SourceBundleException>();
    });

    test('refuses a bundle of another commit under the pin\'s name', () async {
      final other = await pack(second, path('other'));
      File(other).copySync(bundle);
      recorded = {
        'tree-sitter-x': bundleRecord(source(first), await fileSha256(bundle)),
      };

      await check(
        checkRecordedBundle(path('bundles'), source(first), recorded),
      ).throws<SourceBundleException>(
        (it) => it.has((e) => e.message, 'message').contains(second),
      );
    });
  });

  test('supplySources refuses a directory with no build_info.json', () async {
    final toolchain = _toolchain(first);
    Directory(path('downloads')).createSync();

    await check(
      supplySources(
        root: path('root'),
        toolchain: toolchain,
        entries: const [],
        sourceRoot: path('src'),
        bundleDirectory: path('out'),
        patchRoot: path('root'),
        recordedBundles: (
          directory: path('downloads'),
          release: 'v1.1.0',
          commit: _commit,
        ),
      ),
    ).throws<GrammarSourceException>(
      (it) =>
          it.has((e) => e.message, 'message').contains('no build_info.json'),
    );
  });

  group('a build_info.json of a platform', () {
    Map<String, Object?> info(BuildPlatform platform) => {
      'release': 'v1.1.0',
      'repository': {'commit': _commit},
      'platform': platform.id,
      'toolchain': {'clang': 'clang version 21.1.8'},
    };

    test('of macOS or Windows is never asked for the toolchain fields of '
        'Linux', () {
      for (final platform in [
        BuildPlatform.macosArm64,
        BuildPlatform.windowsArm64,
        BuildPlatform.windowsX64,
      ]) {
        check(
          because: platform.id,
          buildRecordProblems(
            info(platform),
            release: 'v1.1.0',
            commit: _commit,
            source: 'build_info.json',
            platform: platform,
          ),
        ).isEmpty();
      }
    });

    test('of Linux lacking the toolchain fields of Linux is refused', () {
      check(
        buildRecordProblems(
          info(BuildPlatform.linuxArm64),
          release: 'v1.1.0',
          commit: _commit,
          source: 'build_info.json',
          platform: BuildPlatform.linuxArm64,
        ),
      ).deepEquals([
        for (final key in linuxToolchainKeys)
          'build_info.json records no toolchain.$key',
      ]);
    });

    test('of another platform than a Linux build reads is refused for its '
        'platform alone', () {
      check(
        buildRecordProblems(
          info(BuildPlatform.macosArm64),
          release: 'v1.1.0',
          commit: _commit,
          source: 'build_info.json',
          platform: BuildPlatform.linuxArm64,
        ),
      ).deepEquals([
        'build_info.json records the platform macos-arm64, not linux-arm64',
      ]);
    });
  });

  group('a release\'s build_info.json', () {
    Map<String, Object?> info({Object? release = 'v1.1.0', Object? commit}) => {
      'release': release,
      'repository': {'commit': commit ?? _commit},
      'sources': const <String, Object?>{},
    };

    test('of the release and commit a build reads is its own', () {
      check(
        buildRecordProblems(
          info(),
          release: 'v1.1.0',
          commit: _commit,
          source: 'build_info.json',
        ),
      ).isEmpty();
    });

    test('of another release or commit is refused', () {
      check(
        buildRecordProblems(
          info(release: 'v1.0.0'),
          release: 'v1.1.0',
          commit: _commit,
          source: 'build_info.json',
        ),
      ).deepEquals(['build_info.json records the release v1.0.0, not v1.1.0']);
      check(
        buildRecordProblems(
          info(commit: '1' * 40),
          release: 'v1.1.0',
          commit: _commit,
          source: 'build_info.json',
        ),
      ).deepEquals([
        'build_info.json records the commit ${'1' * 40}, not $_commit',
      ]);
      check(
        buildRecordProblems(
          {'sources': const <String, Object?>{}},
          release: 'v1.1.0',
          commit: _commit,
          source: 'build_info.json',
        ),
      ).deepEquals([
        'build_info.json records the release null, not v1.1.0',
        'build_info.json records the commit null, not $_commit',
      ]);
    });

    test('of a release is read by a build of no release at its commit', () {
      // Every published build_info.json records its tag, so a build
      // without --release checks the commit alone.
      check(
        buildRecordProblems(
          info(release: 'v1.1.0'),
          release: null,
          commit: _commit,
          source: 'build_info.json',
        ),
      ).isEmpty();
      check(
        buildRecordProblems(
          info(release: 'v1.1.0', commit: '1' * 40),
          release: null,
          commit: _commit,
          source: 'build_info.json',
        ),
      ).deepEquals([
        'build_info.json records the commit ${'1' * 40}, not $_commit',
      ]);
    });

    test('of a release passes a build of no release at its commit on to '
        'its bundles', () async {
      Directory(path('downloads')).createSync();
      File(
        path('downloads/build_info.json'),
      ).writeAsStringSync(jsonEncode(info(release: 'v1.1.0')));

      // The record is accepted, so the build goes on to the runtime's
      // bundle, which this record does not list.
      await check(
        supplySources(
          root: path('root'),
          toolchain: _toolchain(first),
          entries: const [],
          sourceRoot: path('src'),
          bundleDirectory: path('out'),
          patchRoot: path('root'),
          recordedBundles: (
            directory: path('downloads'),
            release: null,
            commit: _commit,
          ),
        ),
      ).throws<Exception>(
        (it) => it
            .has((e) => '$e', 'text')
            .not((it) => it.contains('is not the record of this build')),
      );
    });

    test('of another release is refused before any bundle is read', () async {
      Directory(path('downloads')).createSync();
      File(
        path('downloads/build_info.json'),
      ).writeAsStringSync(jsonEncode(info(release: 'v1.0.0')));

      await check(
        supplySources(
          root: path('root'),
          toolchain: _toolchain(first),
          entries: const [],
          sourceRoot: path('src'),
          bundleDirectory: path('out'),
          patchRoot: path('root'),
          recordedBundles: (
            directory: path('downloads'),
            release: 'v1.1.0',
            commit: _commit,
          ),
        ),
      ).throws<GrammarSourceException>(
        (it) => it.has((e) => e.message, 'message')
          ..contains(
            '\n  build_info.json records the release v1.0.0, not v1.1.0\n',
          )
          ..contains('download the assets of v1.1.0'),
      );
      check(Directory(path('out')).existsSync()).isFalse();
    });
  });

  group('supplySources holds every tree to the digest its pin records', () {
    late FixtureRepository runtime;
    late String pinned;
    late String other;

    setUp(() async {
      runtime = await FixtureRepository.create(path('root/tree-sitter'));
      pinned = await runtime.commit({'lib/api.h': bytes('int ts(void);\n')});
      other = await runtime.commit({'lib/api.h': bytes('int ts(int);\n')});
    });

    Toolchain toolchain(String filesSha256) => Toolchain.parse(
      jsonEncode({
        'treeSitter': {
          'tag': 'v0.27.0',
          'commit': pinned,
          'filesSha256': filesSha256,
        },
        'treeSitterCli': {
          'version': '0.27.0',
          'asset': 'tree-sitter-macos-arm64.gz',
          'sha256': _cliSha256,
        },
        'macos': {'arch': 'arm64', 'deploymentTarget': '13.0'},
      }),
    );

    Future<Map<String, Map<String, Object?>>> supply(
      Toolchain toolchain, {
      String? recordedBundles,
    }) => supplySources(
      root: path('root'),
      toolchain: toolchain,
      entries: const [],
      sourceRoot: path('src'),
      bundleDirectory: path('out'),
      patchRoot: path('root'),
      recordedBundles: recordedBundles == null
          ? null
          : (directory: recordedBundles, release: 'v1.1.0', commit: _commit),
    );

    Future<String> digestOf(String commit) async =>
        filesDigest(await committedFiles(runtime.path, commit));

    test('an object store tree with the recorded digest is supplied', () async {
      final records = await supply(toolchain(await digestOf(pinned)));

      check(records['tree-sitter']!['commit']).equals(pinned);
    });

    test('an object store tree with another digest is refused', () async {
      await check(supply(toolchain('0' * 64))).throws<GrammarSourceException>(
        (it) => it.has((e) => e.message, 'message')
          ..contains('the pin records ${'0' * 64}')
          ..contains('--record-files'),
      );
    });

    test(
      'a forged bundle that matches its build_info.json is refused',
      () async {
        final pin = toolchain(await digestOf(pinned));
        final name = PinnedSource(
          name: 'tree-sitter',
          url: runtimeRepositoryUrl,
          commit: pinned,
          filesSha256: pin.treeSitterFilesSha256,
        ).bundleName;
        Directory(path('downloads')).createSync();
        final bundle = path('downloads/$name');
        // Other content, packed under the pinned bundle's name, with the
        // commit in its header rewritten to the pinned one.
        await packBundle(runtime.path, other, bundle);
        final tar = latin1.decode(gzip.decode(File(bundle).readAsBytesSync()));
        File(bundle).writeAsBytesSync(
          gzip.encode(latin1.encode(tar.replaceAll(other, pinned))),
        );
        final recorded = {
          'tree-sitter': {
            'url': runtimeRepositoryUrl,
            'commit': pinned,
            'file': 'sources/$name',
            'sha256': await fileSha256(bundle),
          },
        };
        File(path('downloads/build_info.json')).writeAsStringSync(
          jsonEncode({
            'release': 'v1.1.0',
            'repository': {'commit': _commit},
            'sources': recorded,
          }),
        );
        final source = pinnedSources(pin, const []).single;

        await checkRecordedBundle(path('downloads'), source, recorded);
        await check(
          supply(pin, recordedBundles: path('downloads')),
        ).throws<GrammarSourceException>(
          (it) => it
              .has((e) => e.message, 'message')
              .contains('the bundle is not the source the pin names'),
        );
      },
    );
  });
}
