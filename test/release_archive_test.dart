import 'dart:io';

import 'package:checks/checks.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../tool/src/release_archive.dart';

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
  });
}
