import 'dart:io';

import 'package:checks/checks.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../tool/src/files_digest.dart';
import '../tool/src/source_bundles.dart';
import '../tool/src/tar.dart';
import '../tool/src/tree_sitter_cli.dart';
import 'support/git_fixture.dart';

void main() {
  test('only macOS computes digests with shasum: Windows has none, nor '
      'has a minimal Linux image, where it comes with Perl', () {
    check(sha256InDart('macos')).isFalse();
    check(sha256InDart('linux')).isTrue();
    check(sha256InDart('windows')).isTrue();
    check(sha256InDart()).equals(!Platform.isMacOS);
  });

  group('with no shasum to run', () {
    late Directory scratch;
    late String file;
    final content = bytes('digest me\n');
    final contentSha256 = dartSha256(content);

    setUp(() {
      scratch = Directory.systemTemp.createTempSync('no_shasum_test');
      file = p.join(scratch.path, 'file');
      File(file).writeAsBytesSync(content);
      shasumExecutable = p.join(scratch.path, 'no-such-shasum');
    });

    tearDown(() {
      shasumExecutable = '/usr/bin/shasum';
      scratch.deleteSync(recursive: true);
    });

    test('a build off macOS computes every digest in Dart', () async {
      check(await fileSha256(file)).equals(contentSha256);
      check(await sha256Of(file)).equals(contentSha256);
      check(await filesDigest(const [])).equals(dartSha256(const <int>[]));
    }, testOn: '!mac-os');

    test('a build on macOS runs the shasum it names', () async {
      await check(fileSha256(file)).throws<ProcessException>();
      await check(sha256Of(file)).throws<ProcessException>();
      await check(filesDigest(const [])).throws<ProcessException>();
    }, testOn: 'mac-os');
  });

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
    if (Platform.isWindows) {
      // NTFS has no execute bit for chmod to set, and a build on Windows
      // unpacks no symbolic link, so the fixture records the bit in the
      // index alone and commits no link.
      await upstream.git(['update-index', '--chmod=+x', 'bin/run']);
    } else {
      await Process.run('/bin/chmod', [
        '755',
        p.join(upstream.path, 'bin/run'),
      ]);
      Link(p.join(upstream.path, 'link')).createSync('src/parser.c');
    }
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
      if (!Platform.isWindows) '120000 link',
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
    if (Platform.isWindows) {
      // The bit unpackedFiles reads on Windows is the one the bundle gave.
      unpackedModes[p.normalize(p.absolute(tree))]!['bin/run'] = 0x1a4;
    } else {
      await Process.run('/bin/chmod', ['644', p.join(tree, 'bin/run')]);
    }
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

    // Computed by another tool than the code under test: shasum on macOS,
    // and on Windows the openssl Git for Windows carries.
    final shasum = Platform.isWindows
        ? await Process.run('openssl', ['dgst', '-sha256', '-r', listing.path])
        : await Process.run('/usr/bin/shasum', ['-a', '256', listing.path]);
    check(digest).equals('${shasum.stdout}'.split(' ').first);
    check(filesDigestPattern.hasMatch(digest)).isTrue();
  });
}
