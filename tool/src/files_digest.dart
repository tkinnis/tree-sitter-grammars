/// The digest a pin records of the files its tree holds, so a tree supplied
/// from anywhere (a git object store or a downloaded source bundle) is
/// checked against the value committed beside the pin.
///
/// The digest is the sha256 of the tree's file list: for every file, its
/// git mode, its blob id and its path, as `<mode> <blob>\t<path>` followed
/// by a NUL, sorted by the path's UTF-8 bytes. Submodule entries are left
/// out, since a tree extracted by `git archive` carries no files for them.
/// Blob ids and modes are git's own, so the digest depends on no tool's
/// version.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'git.dart';

/// One file of a tree: its git mode, its blob id and its path.
typedef TreeFile = ({String mode, String blob, String path});

/// Thrown when a tree's files cannot be listed or hashed.
final class FilesDigestException implements Exception {
  const FilesDigestException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Matches a `filesSha256` value.
final filesDigestPattern = RegExp(r'^[0-9a-f]{64}$');

/// The digest of [files].
Future<String> filesDigest(List<TreeFile> files) async {
  final sorted = [...files]..sort((a, b) => _compareBytes(a.path, b.path));
  final listing = BytesBuilder(copy: false);
  for (final file in sorted) {
    listing
      ..add(utf8.encode('${file.mode} ${file.blob}\t${file.path}'))
      ..addByte(0);
  }
  final shasum = await Process.start('/usr/bin/shasum', ['-a', '256']);
  shasum.stdin.add(listing.takeBytes());
  await shasum.stdin.close();
  final output = shasum.stdout.transform(utf8.decoder).join();
  final errors = shasum.stderr.transform(utf8.decoder).join();
  if (await shasum.exitCode != 0) {
    throw FilesDigestException('shasum failed: ${await errors}');
  }
  return (await output).split(' ').first;
}

int _compareBytes(String a, String b) {
  final x = utf8.encode(a);
  final y = utf8.encode(b);
  for (var i = 0; i < x.length && i < y.length; i++) {
    if (x[i] != y[i]) return x[i] - y[i];
  }
  return x.length - y.length;
}

/// The files of [commit]'s tree in the git object store [directory],
/// submodules left out.
Future<List<TreeFile>> committedFiles(String directory, String commit) async {
  final listing = await runIsolatedGit(directory, [
    'ls-tree',
    '-r',
    '-z',
    '--full-tree',
    commit,
  ]);
  return [
    for (final record in listing.split('\x00').where((r) => r.isNotEmpty))
      if (_blob(record) case final file?) file,
  ];
}

TreeFile? _blob(String record) {
  final tab = record.indexOf('\t');
  final [mode, type, blob] = record.substring(0, tab).split(' ');
  return type == 'blob'
      ? (mode: mode, blob: blob, path: _checkedPath(record.substring(tab + 1)))
      : null;
}

String _checkedPath(String path) {
  if (path.contains('�')) {
    throw FilesDigestException('$path: a path that is not UTF-8');
  }
  return path;
}

/// The files under [directory], each with the mode and blob id git would
/// record for it: a symbolic link as mode 120000 whose blob is its target,
/// a file with its owner's execute bit as 100755, any other as 100644.
/// Directories carry nothing of their own.
Future<List<TreeFile>> unpackedFiles(String directory) async {
  Future<String> git(List<String> arguments, {String? input}) =>
      runIsolatedGit(Directory.systemTemp.path, arguments, input: input);
  final files = <TreeFile>[];
  final regular = <(String, String)>[];
  for (final entity in Directory(
    directory,
  ).listSync(recursive: true, followLinks: false)) {
    final path = _checkedPath(
      p.posix.joinAll(p.split(p.relative(entity.path, from: directory))),
    );
    switch (entity) {
      case Link():
        final blob = await git([
          'hash-object',
          '--no-filters',
          '--stdin',
        ], input: entity.targetSync());
        files.add((mode: '120000', blob: blob.trim(), path: path));
      case File():
        if (path.contains('\n')) {
          throw FilesDigestException('$path: a path with a newline');
        }
        final executable = entity.statSync().mode & 0x40 != 0;
        regular.add((path, executable ? '100755' : '100644'));
      default:
        break;
    }
  }
  if (regular.isEmpty) return files;
  final blobs = (await git(
    ['hash-object', '--no-filters', '--stdin-paths'],
    input: '${regular.map((f) => p.join(directory, f.$1)).join('\n')}\n',
  )).split('\n').where((line) => line.isNotEmpty).toList();
  if (blobs.length != regular.length) {
    throw FilesDigestException(
      'git hash-object answered ${blobs.length} of ${regular.length} paths',
    );
  }
  for (final (index, (path, mode)) in regular.indexed) {
    files.add((mode: mode, blob: blobs[index], path: path));
  }
  return files;
}
