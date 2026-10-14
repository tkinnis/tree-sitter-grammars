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

List<TarMember> _members(List<int> gz) =>
    readTar(Uint8List.fromList(gzip.decode(gz)));

/// Packs the files of [fixtureArchiveFiles] for [platform], each holding
/// what [contents] gives for its path, as a `--release` build packs
/// `output/`: [archiveFiles] lists them, [normalizeArchiveFiles] gives
/// them the archive's modes and time, and [packArchive], the real packer
/// of this host, writes the archive. Returns the archive's path, beside
/// the output directory in [directory].
Future<String> _pack(
  Directory directory,
  BuildPlatform platform,
  String Function(String file) contents,
) async {
  final output = p.join(directory.path, 'output');
  for (final file in fixtureArchiveFiles(platform)) {
    File(p.join(output, file))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(contents(file));
  }
  final files = archiveFiles(output, platform: platform);
  await normalizeArchiveFiles(output, files, 0);
  final archive = p.join(directory.path, platform.releaseArchiveName);
  await packArchive(output, files, archive);
  return archive;
}

void main() {
  // A release archive the real packer writes, a handful of members, with
  // a build_info.json at its root.
  late String packed;
  late Directory directory;

  setUpAll(() async {
    directory = Directory.systemTemp.createTempSync('release_archive_root');
    packed = await _pack(
      directory,
      BuildPlatform.linuxArm64,
      (file) => file == 'build_info.json'
          ? jsonEncode({'release': 'v0.0.1', 'platform': 'linux-arm64'})
          : '$file\n',
    );
  });
  tearDownAll(() => directory.deleteSync(recursive: true));

  test('a release archive holds its files at the root, with no top-level '
      'directory', () {
    final members = _members(File(packed).readAsBytesSync());

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
    final bytes = await tarGzRootFile(packed, 'build_info.json');

    check(bytes).isNotNull();
    check(
      jsonDecode(utf8.decode(bytes!)) as Map<String, Object?>,
    ).containsKey('release');
    check(await tarGzFile(packed, 'build_info.json')).isNull();
    check(await tarGzRootFile(packed, 'missing.json')).isNull();
    check(await tarGzRootFile(packed, 'dylibs/ada/libada.so')).isNotNull();
  });

  test('attach and finalize read the build_info.json of a real release '
      'archive', () async {
    final info = await archiveBuildInfo(packed);

    check(info['release']).equals('v0.0.1');
    check(info['platform']).equals('linux-arm64');
  });

  test('the fixtures the attach and finalize tests build have the layout '
      'the real packer writes', () async {
    final directory = Directory.systemTemp.createTempSync('layout');
    addTearDown(() => directory.deleteSync(recursive: true));
    const platform = BuildPlatform.linuxArm64;
    final archive = await _pack(directory, platform, (file) => '$file\n');

    final real = _members(File(archive).readAsBytesSync());
    final fixture = _members(
      releaseArchiveBytes(platform, {'release': 'v0.0.1'}),
    );

    check(fixture.map((m) => m.path)).deepEquals(real.map((m) => m.path));
    check(fixture.map((m) => m.mode)).deepEquals(real.map((m) => m.mode));
    check(fixture.map((m) => m.type)).deepEquals(real.map((m) => m.type));
  }, testOn: 'mac-os || linux');
}
