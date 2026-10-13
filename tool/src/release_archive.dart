/// Packs `output/` into the release archive, byte for byte the same each
/// time the same build is packed.
///
/// On macOS and Linux `/usr/bin/tar` and `/usr/bin/gzip` pack it from
/// files whose modes and times `chmod` and `touch` have set: bsdtar on
/// macOS, with [tarArguments], and GNU tar on Linux, with
/// [gnuTarArguments], which ask each for a ustar stream of the same
/// layout, modes, owners and times. The two tools' bytes still differ (the
/// device fields of a header, for one), so each platform's archive is the
/// same bytes only from its own tar. Windows has neither tool at a fixed
/// path, nor modes to set, so there `tar.dart` writes headers from the same
/// rules in Dart and `dart:io`'s zlib compresses them.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'build_platform.dart';
import 'tar.dart';

/// Thrown when the archive cannot be packed.
final class ArchiveException implements Exception {
  const ArchiveException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The top-level entries of `output/` a macOS archive carries; `dylibs/`
/// and `queries/` contribute every file beneath them.
const archiveEntries = [
  'libtree-sitter.dylib',
  'dylibs',
  'queries',
  'manifest.json',
  'build_info.json',
  'THIRD_PARTY_NOTICES.md',
];

/// The top-level entries of `output/` the archive of [platform] carries:
/// [archiveEntries], with the runtime as [platform] names it.
List<String> archiveEntriesOf(BuildPlatform platform) => [
  platform.runtimeFileName,
  ...archiveEntries.skip(1),
];

/// Every file the archive of [platform] carries, relative to
/// [outputDirectory], sorted by code unit.
///
/// Throws an [ArchiveException] when an entry of [archiveEntriesOf] is
/// missing, or when anything under it is neither a file nor a directory.
List<String> archiveFiles(
  String outputDirectory, {
  BuildPlatform platform = BuildPlatform.macosArm64,
}) {
  final files = <String>[];
  for (final entry in archiveEntriesOf(platform)) {
    final path = p.join(outputDirectory, entry);
    switch (FileSystemEntity.typeSync(path, followLinks: false)) {
      case FileSystemEntityType.file:
        files.add(entry);
      case FileSystemEntityType.directory:
        for (final entity in Directory(
          path,
        ).listSync(recursive: true, followLinks: false)) {
          final relative = p.posix.joinAll(
            p.split(p.relative(entity.path, from: outputDirectory)),
          );
          switch (entity) {
            case File():
              files.add(relative);
            case Directory():
              break;
            default:
              throw ArchiveException('$relative is not a file or directory');
          }
        }
      default:
        throw ArchiveException('output has no $entry');
    }
  }
  return files..sort();
}

/// Gives every one of [files] and every directory holding them the mode and
/// time the archive records: 0755 for a library and a directory, 0644 for
/// anything else, and [epoch] (seconds since 1970, UTC) as the time.
///
/// On Windows only the files' times are set: NTFS has no modes, and
/// [packArchive] writes each file's mode by [_archiveMode] instead.
Future<void> normalizeArchiveFiles(
  String outputDirectory,
  List<String> files,
  int epoch,
) async {
  if (Platform.isWindows) {
    final time = DateTime.fromMillisecondsSinceEpoch(epoch * 1000, isUtc: true);
    for (final file in files) {
      File(p.join(outputDirectory, file)).setLastModifiedSync(time);
    }
    return;
  }
  final directories = {
    for (final file in files)
      for (
        var directory = p.posix.dirname(file);
        directory != '.';
        directory = p.posix.dirname(directory)
      )
        directory,
  }.toList()..sort();
  final executable = [
    ...directories,
    for (final file in files)
      if (BuildPlatform.isAnyLibrary(file)) file,
  ];
  final plain = [
    for (final file in files)
      if (!BuildPlatform.isAnyLibrary(file)) file,
  ];
  final stamp = _touchStamp(epoch);
  for (final (executable, arguments) in [
    ('/bin/chmod', ['0755', ...executable]),
    ('/bin/chmod', ['0644', ...plain]),
    ('/usr/bin/touch', ['-h', '-t', stamp, ...files, ...directories]),
  ]) {
    final result = await Process.run(
      executable,
      arguments,
      workingDirectory: outputDirectory,
      environment: {'TZ': 'UTC'},
    );
    if (result.exitCode != 0) {
      throw ArchiveException('$executable failed: ${result.stderr}');
    }
  }
}

/// [epoch] in the `[[CC]YY]MMDDhhmm[.SS]` form `touch -t` reads, in UTC.
String _touchStamp(int epoch) {
  final time = DateTime.fromMillisecondsSinceEpoch(epoch * 1000, isUtc: true);
  String two(int value) => value.toString().padLeft(2, '0');
  return '${time.year.toString().padLeft(4, '0')}${two(time.month)}'
      '${two(time.day)}${two(time.hour)}${two(time.minute)}.'
      '${two(time.second)}';
}

/// The bsdtar arguments that write the files read from standard input, as
/// a ustar stream owned by root:wheel with no macOS metadata, extended
/// attributes, ACLs or file flags.
const tarArguments = [
  '-n',
  '--no-mac-metadata',
  '--no-xattrs',
  '--no-acls',
  '--no-fflags',
  '--uid',
  '0',
  '--gid',
  '0',
  '--uname',
  'root',
  '--gname',
  'wheel',
  '--format',
  'ustar',
  '-cf',
  '-',
  '-T',
  '-',
];

/// The GNU tar arguments that write the files read from standard input,
/// each name as it is and none of a directory's contents, as a ustar
/// stream of the layout, modes, owners and times [tarArguments] asks bsdtar
/// for: owned by root:wheel, with no extended attributes, ACLs or SELinux
/// contexts.
const gnuTarArguments = [
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
];

/// The mode the archive gives [file] on Windows, where the file has none
/// of its own: 0755 for a library, as `chmod` gives one on macOS and
/// Linux, and 0644 for anything else.
int _archiveMode(String file) =>
    BuildPlatform.isAnyLibrary(file) ? 0x1ed /* 0755 */ : 0x1a4 /* 0644 */;

/// Writes [files], relative to [outputDirectory], in their order into the
/// gzip-compressed tar [archive].
///
/// `/usr/bin/tar` writes the stream with [tarArguments] and
/// `COPYFILE_DISABLE=1` on macOS, or [gnuTarArguments] on Linux, and
/// `/usr/bin/gzip -n -9` compresses it with no
/// name or time, so the same files with the same modes and times pack to
/// the same bytes. On Windows [ustar] writes the same kind of stream, each
/// file owned by root:wheel with its [_archiveMode] and the time
/// [normalizeArchiveFiles] gave it, and [gzipCompress] compresses it.
Future<void> packArchive(
  String outputDirectory,
  List<String> files,
  String archive,
) async {
  if (Platform.isWindows) {
    final stream = ustar([
      for (final file in files)
        (
          path: file,
          bytes: File(p.join(outputDirectory, file)).readAsBytesSync(),
          mode: _archiveMode(file),
          epoch:
              File(
                p.join(outputDirectory, file),
              ).lastModifiedSync().millisecondsSinceEpoch ~/
              1000,
        ),
    ]);
    File(archive).writeAsBytesSync(gzipCompress(stream), flush: true);
    return;
  }
  final tar = await Process.start(
    '/usr/bin/tar',
    Platform.isMacOS ? tarArguments : gnuTarArguments,
    workingDirectory: outputDirectory,
    environment: {'COPYFILE_DISABLE': '1', 'PATH': '/usr/bin:/bin'},
    includeParentEnvironment: false,
  );
  final gzip = await Process.start('/usr/bin/gzip', ['-n', '-9']);
  final tarErrors = tar.stderr.transform(utf8.decoder).join();
  final gzipErrors = gzip.stderr.transform(utf8.decoder).join();
  final compressed = tar.stdout.pipe(gzip.stdin);
  final written = gzip.stdout.pipe(File(archive).openWrite());
  tar.stdin.write(files.map((file) => '$file\n').join());
  await tar.stdin.close();
  final tarExit = await tar.exitCode;
  await compressed;
  final gzipExit = await gzip.exitCode;
  await written;
  if (tarExit != 0 || gzipExit != 0) {
    if (File(archive).existsSync()) File(archive).deleteSync();
    throw ArchiveException(
      'tar exited $tarExit, gzip exited $gzipExit: '
      '${await tarErrors}${await gzipErrors}',
    );
  }
}
