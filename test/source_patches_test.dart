import 'dart:convert';
import 'dart:io';

import 'package:checks/checks.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../tool/src/files_digest.dart';
import '../tool/src/grammar_sources.dart';
import '../tool/src/source_bundles.dart';
import '../tool/src/source_patches.dart';
import '../tool/src/toolchain.dart';
import 'support/git_fixture.dart';

const _patch = 'patches/tree-sitter-x/bound.patch';

void main() {
  late Directory temporary;
  late FixtureRepository upstream;
  late String pinned;

  /// The patch that turns `return 0;` into `return 1;` in `src/scanner.c`,
  /// as `git diff` writes it, with a line of explanation ahead of it.
  late String patchText;

  String path(String relative) => p.join(temporary.path, relative);

  void write(String relative, String text) => File(path(relative))
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(text);

  setUp(() async {
    temporary = Directory.systemTemp.createTempSync('patches_test');
    upstream = await FixtureRepository.create(path('grammars/tree-sitter-x'));
    pinned = await upstream.commit({
      'LICENSE': bytes('grammar licence\n'),
      'src/scanner.c': bytes('int scan(void) {\n  return 0;\n}\n'),
    });
    File(
      p.join(upstream.path, 'src/scanner.c'),
    ).writeAsStringSync('int scan(void) {\n  return 1;\n}\n');
    patchText = 'Return one.\n\n${await upstream.git(['diff'])}\n';
    await upstream.git(['checkout', '--', '.']);
    write(_patch, patchText);
  });

  tearDown(() => temporary.deleteSync(recursive: true));

  /// The pinned tree, extracted into [relative] under the temporary
  /// directory.
  Future<String> extract(String relative) async {
    await extractCommit(upstream.path, pinned, path(relative));
    return path(relative);
  }

  String scanner(String tree) =>
      File(p.join(tree, 'src/scanner.c')).readAsStringSync();

  test('patchedPaths reads the files of every diff --git line', () {
    check(
      patchedPaths(
        'Why.\n\ndiff --git a/src/scanner.c b/src/scanner.c\n'
        '--- a/src/scanner.c\n+++ b/src/scanner.c\n'
        'diff --git a/grammar/src/parser.c b/grammar/src/parser.c\n',
      ),
    ).deepEquals(['src/scanner.c', 'grammar/src/parser.c']);
  });

  group('applyPatches', () {
    test('applies a patch to a tree inside another repository, against '
        'the tree alone', () async {
      // The temporary directory is itself a repository, as build/src lies
      // inside this one.
      await FixtureRepository.create(temporary.path);
      final tree = await extract('build/src/tree-sitter-x');

      await applyPatches(path('.'), [_patch], tree);

      check(scanner(tree)).equals('int scan(void) {\n  return 1;\n}\n');
    });

    test('refuses a patch whose context is not in the tree', () async {
      final tree = await extract('tree');
      File(
        p.join(tree, 'src/scanner.c'),
      ).writeAsStringSync('int scan(void) {\n  return 2;\n}\n');

      await check(
        applyPatches(path('.'), [_patch], tree),
      ).throws<SourcePatchException>(
        (it) => it
            .has((e) => e.message, 'message')
            .startsWith('$_patch does not apply: '),
      );
    });

    test('refuses a patch leading out of the tree', () async {
      final tree = await extract('tree');
      write(
        'patches/tree-sitter-x/escape.patch',
        patchText.replaceAll('src/scanner.c', '../outside.c'),
      );
      write('outside.c', 'int scan(void) {\n  return 0;\n}\n');

      await check(
        applyPatches(path('.'), ['patches/tree-sitter-x/escape.patch'], tree),
      ).throws<SourcePatchException>();
      check(
        File(path('outside.c')).readAsStringSync(),
      ).equals('int scan(void) {\n  return 0;\n}\n');
    });

    test('refuses a missing patch and one that changes nothing', () async {
      final tree = await extract('tree');
      write('patches/tree-sitter-x/empty.patch', 'Only words.\n');

      await check(
        applyPatches(path('.'), ['patches/tree-sitter-x/gone.patch'], tree),
      ).throws<SourcePatchException>(
        (it) => it
            .has((e) => e.message, 'message')
            .equals('patches/tree-sitter-x/gone.patch does not exist'),
      );
      await check(
        applyPatches(path('.'), ['patches/tree-sitter-x/empty.patch'], tree),
      ).throws<SourcePatchException>(
        (it) => it
            .has((e) => e.message, 'message')
            .equals('patches/tree-sitter-x/empty.patch changes no file'),
      );
    });
  });

  group('patchSource', () {
    Future<String> patchedDigest() async {
      final tree = await extract('reference');
      await applyPatches(path('.'), [_patch], tree);
      return filesDigest(await unpackedFiles(tree));
    }

    PinnedSource source(String? patchedSha256) => PinnedSource(
      name: 'tree-sitter-x',
      url: 'https://github.com/example/tree-sitter-x',
      commit: pinned,
      filesSha256: '0' * 64,
      patches: const [_patch],
      patchedSha256: patchedSha256,
    );

    test('accepts a patched tree with the recorded digest', () async {
      final tree = await extract('tree');

      await patchSource(source(await patchedDigest()), path('.'), tree);

      check(scanner(tree)).contains('return 1;');
    });

    test('refuses a patched tree with another digest', () async {
      final tree = await extract('tree');

      await check(
        patchSource(source('1' * 64), path('.'), tree),
      ).throws<SourcePatchException>(
        (it) => it
            .has((e) => e.message, 'message')
            .contains('the pin records ${'1' * 64}'),
      );
    });
  });

  group('patchRecordProblems', () {
    PinnedSource source({List<String> patches = const [_patch]}) =>
        PinnedSource(
          name: 'tree-sitter-x',
          url: 'https://github.com/example/tree-sitter-x',
          commit: pinned,
          filesSha256: '0' * 64,
          patches: patches,
          patchedSha256: patches.isEmpty ? null : '2' * 64,
        );

    test('accepts the record patchRecord makes', () async {
      final record = await patchRecord(source(), path('.'));

      check(await patchRecordProblems(source(), record, path('.'))).isEmpty();
    });

    test('refuses a record of a patch that has changed since', () async {
      final record = await patchRecord(source(), path('.'));
      write(_patch, '$patchText\n');

      check(
        await patchRecordProblems(source(), record, path('.')),
      ).single.contains('the committed patch has');
    });

    test('refuses a record of no patches, and patches on a source with '
        'none', () async {
      final record = await patchRecord(source(), path('.'));

      check(
        await patchRecordProblems(source(), const {}, path('.')),
      ).deepEquals([
        'build_info.json records the patches none; grammars.json lists '
            '$_patch',
        'build_info.json records patchedSha256 null; grammars.json records '
            '${'2' * 64}',
      ]);
      check(
        await patchRecordProblems(source(patches: const []), record, path('.')),
      ).length.equals(2);
    });
  });

  test('supplySources patches a tree, bundles it unpatched and records '
      'the patches', () async {
    final runtime = await FixtureRepository.create(path('root/tree-sitter'));
    final runtimeCommit = await runtime.commit({
      'lib/api.h': bytes('int t;\n'),
    });
    final toolchain = Toolchain.parse(
      jsonEncode({
        'treeSitter': {
          'tag': 'v0.27.0',
          'commit': runtimeCommit,
          'filesSha256': await filesDigest(
            await committedFiles(runtime.path, runtimeCommit),
          ),
        },
        'treeSitterCli': {
          'version': '0.27.0',
          'asset': 'tree-sitter-macos-arm64.gz',
          'sha256':
              '70f7573b2b2e5371a5b58cc5227d2ad981fd5374596b9874e770af486060774e',
        },
        'macos': {'arch': 'arm64', 'deploymentTarget': '13.0'},
      }),
    );
    Directory(path('root/grammars')).createSync(recursive: true);
    // The object store the build fetches from is a clone whose origin is
    // the entry's url.
    await fixtureGit(path('root/grammars'), [
      'clone',
      '--quiet',
      upstream.path,
      'tree-sitter-x',
    ]);
    final reference = await extract('reference');
    await applyPatches(path('.'), [_patch], reference);
    final entry = <String, Object?>{
      'url': upstream.path,
      'commit': pinned,
      'filesSha256': await filesDigest(
        await committedFiles(upstream.path, pinned),
      ),
      'license': 'MIT',
      'patches': [_patch],
      'patchedSha256': await filesDigest(await unpackedFiles(reference)),
    };

    final records = await supplySources(
      root: path('root'),
      toolchain: toolchain,
      entries: [entry],
      sourceRoot: path('src'),
      bundleDirectory: path('out'),
      patchRoot: path('.'),
    );

    check(scanner(path('src/tree-sitter-x'))).contains('return 1;');
    check(
      await bundleFile(
        path('out/tree-sitter-x-$pinned.tar.gz'),
        'src/scanner.c',
      ),
    ).isNotNull().contains('return 0;');
    check(records['tree-sitter-x']!)
      ..has(
        (it) => it['patchedSha256'],
        'patchedSha256',
      ).equals(entry['patchedSha256'])
      ..has((it) => (it['patches']! as List).single, 'patch')
          .isA<Map<String, Object?>>()
          .has((it) => it['file'], 'file')
          .equals(_patch);
    check(records['tree-sitter']!).not((it) => it.containsKey('patches'));
  });
}
