import 'dart:convert';
import 'dart:io';

import 'package:checks/checks.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../tool/src/files_digest.dart';
import '../tool/src/grammar_sources.dart';
import '../tool/src/source_bundles.dart';
import '../tool/src/toolchain.dart';
import 'support/git_fixture.dart';

const _cliSha256 =
    '70f7573b2b2e5371a5b58cc5227d2ad981fd5374596b9874e770af486060774e';

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
  });

  test('the packing tools report their versions', () async {
    final versions = await packingToolVersions();

    check(versions.keys).unorderedEquals(['git', 'gzip', 'tar']);
    check(versions['git']!).startsWith('git version ');
    check(versions['gzip']!).contains('gzip');
    check(versions['tar']!).contains('tar');
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
    final toolchain = Toolchain.parse(
      jsonEncode({
        'treeSitter': {
          'tag': 'v0.27.0',
          'commit': first,
          'filesSha256': '0' * 64,
        },
        'treeSitterCli': {
          'version': '0.27.0',
          'asset': 'tree-sitter-macos-arm64.gz',
          'sha256': _cliSha256,
        },
        'macos': {'arch': 'arm64', 'deploymentTarget': '13.0'},
      }),
    );
    Directory(path('downloads')).createSync();

    await check(
      supplySources(
        root: path('root'),
        toolchain: toolchain,
        entries: const [],
        sourceRoot: path('src'),
        bundleDirectory: path('out'),
        patchRoot: path('root'),
        recordedBundles: path('downloads'),
      ),
    ).throws<GrammarSourceException>(
      (it) =>
          it.has((e) => e.message, 'message').contains('no build_info.json'),
    );
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
      recordedBundles: recordedBundles,
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
        File(
          path('downloads/build_info.json'),
        ).writeAsStringSync(jsonEncode({'sources': recorded}));
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
