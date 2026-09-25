import 'dart:io';

import 'package:checks/checks.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../tool/src/files_digest.dart';
import '../tool/src/source_bundles.dart';
import 'support/git_fixture.dart';

void main() {
  late Directory temporary;
  late FixtureRepository upstream;
  late String commit;

  setUp(() async {
    temporary = Directory.systemTemp.createTempSync('digest_test');
    upstream = await FixtureRepository.create(
      p.join(temporary.path, 'tree-sitter-x'),
    );
    await upstream.commit({
      'src/parser.c': bytes('int parse(void);\n'),
      'bin/run': bytes('#!/bin/sh\n'),
      'z/ä.txt': bytes('umlaut\n'),
    });
    await Process.run('/bin/chmod', ['755', p.join(upstream.path, 'bin/run')]);
    Link(p.join(upstream.path, 'link')).createSync('src/parser.c');
    await upstream.git([
      'update-index',
      '--add',
      '--cacheinfo',
      '160000,0123456789abcdef0123456789abcdef01234567,vendored',
    ]);
    commit = await upstream.commit(const {});
  });

  tearDown(() => temporary.deleteSync(recursive: true));

  Future<String> unpacked() async {
    final bundle = p.join(temporary.path, 'x-$commit.tar.gz');
    await packBundle(upstream.path, commit, bundle);
    final tree = p.join(temporary.path, 'tree');
    await unpackBundle(bundle, tree);
    return tree;
  }

  test('a commit and its unpacked bundle list the same files', () async {
    final committed = await committedFiles(upstream.path, commit);
    final tree = await unpacked();

    check(committed.map((f) => '${f.mode} ${f.path}')).unorderedEquals([
      '100644 src/parser.c',
      '100755 bin/run',
      '100644 z/ä.txt',
      '120000 link',
    ]);
    check(
      await filesDigest(await unpackedFiles(tree)),
    ).equals(await filesDigest(committed));
  });

  test('a changed byte, mode or name changes the digest', () async {
    final tree = await unpacked();
    final original = await filesDigest(await unpackedFiles(tree));

    File(p.join(tree, 'src/parser.c')).writeAsStringSync('int parse(int);\n');
    final changed = await filesDigest(await unpackedFiles(tree));
    await Process.run('/bin/chmod', ['644', p.join(tree, 'bin/run')]);
    final unexecutable = await filesDigest(await unpackedFiles(tree));

    check({original, changed, unexecutable}).length.equals(3);
  });

  test('the digest is the sha256 of the sorted file list', () async {
    final digest = await filesDigest([
      (mode: '100644', blob: 'b' * 40, path: 'b'),
      (mode: '100755', blob: 'a' * 40, path: 'a'),
    ]);
    final listing = File(p.join(temporary.path, 'listing'))
      ..writeAsBytesSync([
        ...'100755 ${'a' * 40}\ta'.codeUnits,
        0,
        ...'100644 ${'b' * 40}\tb'.codeUnits,
        0,
      ]);

    final shasum = await Process.run('/usr/bin/shasum', [
      '-a',
      '256',
      listing.path,
    ]);
    check(digest).equals('${shasum.stdout}'.split(' ').first);
    check(filesDigestPattern.hasMatch(digest)).isTrue();
  });
}
