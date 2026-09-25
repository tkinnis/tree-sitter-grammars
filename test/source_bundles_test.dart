import 'dart:convert';
import 'dart:io';

import 'package:checks/checks.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

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
        'treeSitter': {'tag': 'v0.27.0', 'commit': first},
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
        recordedBundles: path('downloads'),
      ),
    ).throws<GrammarSourceException>(
      (it) =>
          it.has((e) => e.message, 'message').contains('no build_info.json'),
    );
  });
}
