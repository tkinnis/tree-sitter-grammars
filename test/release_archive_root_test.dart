import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../tool/src/attach.dart';
import '../tool/src/build_platform.dart';
import '../tool/src/release_archive.dart';
import '../tool/src/tar.dart';
import 'support/release_fixture.dart';

/// A release archive `packArchive` wrote, a handful of members, kept as
/// the bytes the real packer produced.
const _committed = 'test/support/release-archive-linux-arm64.tar.gz';

List<TarMember> _members(List<int> gz) =>
    readTar(Uint8List.fromList(gzip.decode(gz)));

void main() {
  test('a release archive holds its files at the root, with no top-level '
      'directory', () {
    final members = _members(File(_committed).readAsBytesSync());

    check(members.map((m) => m.path)).deepEquals([
      'THIRD_PARTY_NOTICES.md',
      'build_info.json',
      'dylibs/ada/libada.so',
      'libtree-sitter.so',
      'manifest.json',
      'queries/ada/highlights.scm',
    ]);
  });

  test('the root reader finds build_info.json where a reader that skips a '
      'segment finds nothing', () async {
    final bytes = await tarGzRootFile(_committed, 'build_info.json');

    check(bytes).isNotNull();
    check(
      jsonDecode(utf8.decode(bytes!)) as Map<String, Object?>,
    ).containsKey('release');
    check(await tarGzFile(_committed, 'build_info.json')).isNull();
    check(await tarGzRootFile(_committed, 'missing.json')).isNull();
    check(await tarGzRootFile(_committed, 'dylibs/ada/libada.so')).isNotNull();
  });

  test('attach and finalize read the build_info.json of a real release '
      'archive', () async {
    final info = await archiveBuildInfo(_committed);

    check(info['release']).equals('v0.0.1');
    check(info['platform']).equals('linux-arm64');
  });

  test('the fixtures the attach and finalize tests build have the layout '
      'the real packer writes', () async {
    final directory = Directory.systemTemp.createTempSync('layout');
    addTearDown(() => directory.deleteSync(recursive: true));
    const platform = BuildPlatform.linuxArm64;
    for (final file in fixtureArchiveFiles(platform)) {
      File(p.join(directory.path, file))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('$file\n');
    }
    final files = archiveFiles(directory.path, platform: platform);
    await normalizeArchiveFiles(directory.path, files, 0);
    final packed = p.join(directory.path, 'real.tar.gz');
    await packArchive(directory.path, files, packed);

    final real = _members(File(packed).readAsBytesSync());
    final fixture = _members(
      releaseArchiveBytes(platform, {'release': 'v0.0.1'}),
    );

    check(fixture.map((m) => m.path)).deepEquals(real.map((m) => m.path));
    check(fixture.map((m) => m.mode)).deepEquals(real.map((m) => m.mode));
    check(fixture.map((m) => m.type)).deepEquals(real.map((m) => m.type));
  }, testOn: 'mac-os || linux');
}
