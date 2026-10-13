import 'dart:io';
import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../tool/src/build_platform.dart';
import '../tool/src/release_archive.dart';
import '../tool/src/tar.dart';

/// 2026-01-01T00:00:00Z.
const _epoch = 1767225600;

void main() {
  late Directory output;

  setUp(() {
    output = Directory.systemTemp.createTempSync('archive_test');
    for (final (path, text) in [
      ('libtree-sitter.dylib', 'runtime'),
      ('dylibs/c/libc.dylib', 'grammar'),
      ('dylibs/c/highlights.scm', '(a) @b'),
      ('dylibs/c/config.json', '{}'),
      ('queries/ecma/highlights.scm', '(e) @f'),
      ('manifest.json', '{}'),
      ('build_info.json', '{}'),
      ('THIRD_PARTY_NOTICES.md', 'notices'),
      ('sources/tree-sitter-c-0000.tar.gz', 'not packed'),
      ('grammars-macos-arm64.tar.gz', 'not packed'),
    ]) {
      File(p.join(output.path, path))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(text);
    }
  });

  tearDown(() => output.deleteSync(recursive: true));

  Future<String> pack(String name) async {
    final files = archiveFiles(output.path);
    await normalizeArchiveFiles(output.path, files, _epoch);
    final archive = p.join(
      output.path,
      '..',
      '${p.basename(output.path)}$name',
    );
    await packArchive(output.path, files, archive);
    addTearDown(() => File(archive).deleteSync());
    return archive;
  }

  test('lists every archived file, sorted, and nothing else', () {
    check(archiveFiles(output.path)).deepEquals([
      'THIRD_PARTY_NOTICES.md',
      'build_info.json',
      'dylibs/c/config.json',
      'dylibs/c/highlights.scm',
      'dylibs/c/libc.dylib',
      'libtree-sitter.dylib',
      'manifest.json',
      'queries/ecma/highlights.scm',
    ]);
  });

  test('refuses an output missing an archived entry', () {
    File(p.join(output.path, 'THIRD_PARTY_NOTICES.md')).deleteSync();

    check(() => archiveFiles(output.path))
        .throws<ArchiveException>()
        .has((e) => e.message, 'message')
        .contains('THIRD_PARTY_NOTICES.md');
  });

  test('packs the same files to the same bytes, whatever their time', () async {
    final first = await pack('.a.tar.gz');
    File(
      p.join(output.path, 'manifest.json'),
    ).setLastModifiedSync(DateTime.utc(2030));
    final second = await pack('.b.tar.gz');

    check(
      File(first).readAsBytesSync(),
    ).deepEquals(File(second).readAsBytesSync());
  });

  test('lists the DLLs of a Windows archive, the runtime by its own '
      'name', () {
    File(
      p.join(output.path, 'libtree-sitter.dylib'),
    ).renameSync(p.join(output.path, 'tree-sitter.dll'));
    File(
      p.join(output.path, 'dylibs', 'c', 'libc.dylib'),
    ).renameSync(p.join(output.path, 'dylibs', 'c', 'c.dll'));

    check(
      archiveFiles(output.path, platform: BuildPlatform.windowsArm64),
    ).deepEquals([
      'THIRD_PARTY_NOTICES.md',
      'build_info.json',
      'dylibs/c/c.dll',
      'dylibs/c/config.json',
      'dylibs/c/highlights.scm',
      'manifest.json',
      'queries/ecma/highlights.scm',
      'tree-sitter.dll',
    ]);
    check(() => archiveFiles(output.path))
        .throws<ArchiveException>()
        .has((e) => e.message, 'message')
        .contains('libtree-sitter.dylib');
  });

  test('lists the shared objects of a Linux archive, the runtime by its own '
      'name, and packs them executable', () async {
    File(
      p.join(output.path, 'libtree-sitter.dylib'),
    ).renameSync(p.join(output.path, 'libtree-sitter.so'));
    File(
      p.join(output.path, 'dylibs', 'c', 'libc.dylib'),
    ).renameSync(p.join(output.path, 'dylibs', 'c', 'libc.so'));
    final files = archiveFiles(output.path, platform: BuildPlatform.linuxArm64);

    check(files).deepEquals([
      'THIRD_PARTY_NOTICES.md',
      'build_info.json',
      'dylibs/c/config.json',
      'dylibs/c/highlights.scm',
      'dylibs/c/libc.so',
      'libtree-sitter.so',
      'manifest.json',
      'queries/ecma/highlights.scm',
    ]);
    check(() => archiveFiles(output.path))
        .throws<ArchiveException>()
        .has((e) => e.message, 'message')
        .contains('libtree-sitter.dylib');

    await normalizeArchiveFiles(output.path, files, _epoch);
    final archive = '${output.path}.tar.gz';
    await packArchive(output.path, files, archive);
    addTearDown(() => File(archive).deleteSync());
    final members = readTar(
      Uint8List.fromList(gzip.decode(File(archive).readAsBytesSync())),
    );
    check(members.map((m) => m.path)).deepEquals(files);
    for (final member in members) {
      check(member.mode).equals(member.path.endsWith('.so') ? 0x1ed : 0x1a4);
    }
  }, testOn: 'linux || windows');

  test('GNU tar is asked, on any host, for the names it reads and none of '
      'their contents, as ustar owned by root:wheel, with no extended '
      'attributes, ACLs or SELinux contexts', () {
    check(gnuTarArguments).deepEquals([
      '--no-recursion',
      '--verbatim-files-from',
      '--no-xattrs',
      '--no-acls',
      '--no-selinux',
      '--owner=root:0',
      '--group=wheel:0',
      '--format=ustar',
      '-cf',
      '-',
      '-T',
      '-',
    ]);
  });

  test('on Windows and Linux, packs root:wheel, the modes and the time, '
      'files only', () async {
    final archive = await pack('.tar.gz');

    final members = readTar(
      Uint8List.fromList(gzip.decode(File(archive).readAsBytesSync())),
    );

    check(members.map((m) => m.path)).deepEquals(archiveFiles(output.path));
    for (final member in members) {
      check(member.mode).equals(member.path.endsWith('.dylib') ? 0x1ed : 0x1a4);
    }
    final header = gzip.decode(File(archive).readAsBytesSync()).sublist(0, 512);
    check(String.fromCharCodes(header.sublist(265, 269))).equals('root');
    check(String.fromCharCodes(header.sublist(297, 302))).equals('wheel');
    check(
      int.parse(String.fromCharCodes(header.sublist(136, 147)), radix: 8),
    ).equals(_epoch);
  }, testOn: 'linux || windows');

  test('records root:wheel, the modes and the time, files only', () async {
    final archive = await pack('.tar.gz');

    final listing = await Process.run('/usr/bin/tar', ['-tvzf', archive]);
    final lines = '${listing.stdout}'.trim().split('\n');

    check(lines).length.equals(8);
    for (final line in lines) {
      final fields = line.split(RegExp(r'\s+'));
      check(fields[2]).equals('root');
      check(fields[3]).equals('wheel');
      check(fields.last).not((it) => it.startsWith('._'));
      check(
        fields[0],
      ).equals(fields.last.endsWith('.dylib') ? '-rwxr-xr-x' : '-rw-r--r--');
    }
    final names = await Process.run(
      '/usr/bin/tar',
      ['-tzf', archive],
      environment: {'TZ': 'UTC'},
    );
    check('${names.stdout}').not((it) => it.contains('sources/'));
    final verbose = await Process.run(
      '/usr/bin/tar',
      ['-tvzf', archive],
      environment: {'TZ': 'UTC'},
    );
    check('${verbose.stdout}').contains('Jan  1  2026');
  }, testOn: 'mac-os');
}
