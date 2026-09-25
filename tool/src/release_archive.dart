/// Packs `output/` into the release archive, byte for byte the same each
/// time the same build is packed.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Thrown when the archive cannot be packed.
final class ArchiveException implements Exception {
  const ArchiveException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The top-level entries of `output/` the archive carries; `dylibs/` and
/// `queries/` contribute every file beneath them.
const archiveEntries = [
  'libtree-sitter.dylib',
  'dylibs',
  'queries',
  'manifest.json',
  'build_info.json',
  'THIRD_PARTY_NOTICES.md',
];

/// Every file the archive carries, relative to [outputDirectory], sorted by
/// code unit.
///
/// Throws an [ArchiveException] when an entry of [archiveEntries] is
/// missing, or when anything under it is neither a file nor a directory.
List<String> archiveFiles(String outputDirectory) {
  final files = <String>[];
  for (final entry in archiveEntries) {
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
/// time the archive records: 0755 for a dylib and a directory, 0644 for
/// anything else, and [epoch] (seconds since 1970, UTC) as the time.
Future<void> normalizeArchiveFiles(
  String outputDirectory,
  List<String> files,
  int epoch,
) async {
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
      if (file.endsWith('.dylib')) file,
  ];
  final plain = [
    for (final file in files)
      if (!file.endsWith('.dylib')) file,
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

/// The `tar` arguments that write [files], read from standard input, as a
/// ustar stream owned by root:wheel with no macOS metadata, extended
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

/// Writes [files], relative to [outputDirectory], in their order into the
/// gzip-compressed tar [archive].
///
/// `/usr/bin/tar` writes the stream with [tarArguments] and
/// `COPYFILE_DISABLE=1`, and `/usr/bin/gzip -n -9` compresses it with no
/// name or time, so the same files with the same modes and times pack to
/// the same bytes.
Future<void> packArchive(
  String outputDirectory,
  List<String> files,
  String archive,
) async {
  final tar = await Process.start(
    '/usr/bin/tar',
    tarArguments,
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
