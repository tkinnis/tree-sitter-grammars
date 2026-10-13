/// Reads and writes the gzip-compressed tar files a build on Windows packs
/// and unpacks, in Dart, where a build on macOS runs `/usr/bin/tar` and
/// `/usr/bin/gzip`.
///
/// Windows has no tar or gzip of fixed path and version that could stand
/// in for those, and NTFS keeps neither the owner nor the executable bit a
/// tar header records, so the archive's headers are written from the rules
/// the macOS build applies with `chmod` and `touch`, and a bundle's modes
/// are read from its headers rather than from the unpacked files.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;

/// Thrown when a tar stream cannot be written or read.
final class TarException implements Exception {
  const TarException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// One regular file a tar stream carries.
typedef TarFile = ({String path, List<int> bytes, int mode, int epoch});

/// One member of a tar stream as [readTar] reads it: a regular file, a
/// symbolic link or a directory.
typedef TarMember = ({
  String path,
  TarMemberType type,
  int mode,
  Uint8List bytes,
  String linkTarget,
});

/// The kinds of member [readTar] returns.
enum TarMemberType { file, symlink, directory }

const _block = 512;

/// [files], in their order, as a ustar stream: each file owned by
/// `root:wheel` (uid and gid 0) with its own mode and time, no directory
/// entries, and the two zero blocks that end the stream.
///
/// A path longer than the 100 bytes of a header's name field is split at
/// a `/` into its 155-byte prefix field, as ustar defines; one that fits
/// neither way throws a [TarException].
Uint8List ustar(List<TarFile> files) {
  final stream = BytesBuilder(copy: false);
  for (final file in files) {
    stream.add(_header(file));
    stream.add(file.bytes);
    final padding = (_block - file.bytes.length % _block) % _block;
    stream.add(Uint8List(padding));
  }
  stream.add(Uint8List(_block * 2));
  return stream.takeBytes();
}

Uint8List _header(TarFile file) {
  final header = Uint8List(_block);
  final (prefix, name) = _splitPath(file.path);
  void field(int offset, int length, List<int> bytes) {
    if (bytes.length > length) {
      throw TarException('${file.path}: a header field overflows');
    }
    header.setRange(offset, offset + bytes.length, bytes);
  }

  List<int> octal(int value, int length) =>
      ascii.encode('${value.toRadixString(8).padLeft(length - 1, '0')}\x00');

  field(0, 100, utf8.encode(name));
  field(100, 8, octal(file.mode, 8));
  field(108, 8, octal(0, 8));
  field(116, 8, octal(0, 8));
  field(124, 12, octal(file.bytes.length, 12));
  field(136, 12, octal(file.epoch, 12));
  field(148, 8, ascii.encode(' ' * 8));
  header[156] = 0x30; // '0', a regular file
  field(257, 6, ascii.encode('ustar\x00'));
  field(263, 2, ascii.encode('00'));
  field(265, 32, ascii.encode('root'));
  field(297, 32, ascii.encode('wheel'));
  field(329, 8, octal(0, 8));
  field(337, 8, octal(0, 8));
  field(345, 155, utf8.encode(prefix));
  final checksum = header.fold<int>(0, (sum, byte) => sum + byte);
  field(
    148,
    8,
    ascii.encode('${checksum.toRadixString(8).padLeft(6, '0')}\x00 '),
  );
  return header;
}

/// [path] as ustar's prefix and name fields hold it.
(String, String) _splitPath(String path) {
  final bytes = utf8.encode(path);
  if (bytes.length <= 100) return ('', path);
  for (var index = path.length - 1; index > 0; index--) {
    if (path[index] != '/') continue;
    final prefix = path.substring(0, index);
    final name = path.substring(index + 1);
    if (utf8.encode(prefix).length <= 155 && utf8.encode(name).length <= 100) {
      return (prefix, name);
    }
  }
  throw TarException('$path is too long for a ustar header');
}

/// Every member of the tar stream [bytes], in order, with each path as
/// the pax extended header before it gives it, if one does.
///
/// Reads what `git archive` writes (ustar with pax extended headers, and a
/// global header naming the commit, which is skipped) and what the macOS
/// build's `/usr/bin/tar` writes. Throws a [TarException] for a header
/// whose checksum is wrong and for a member of any other type.
List<TarMember> readTar(Uint8List bytes) {
  final members = <TarMember>[];
  var offset = 0;
  Map<String, String> extended = const {};
  while (offset + _block <= bytes.length) {
    final header = Uint8List.sublistView(bytes, offset, offset + _block);
    if (header.every((byte) => byte == 0)) break;
    _requireChecksum(header, offset);
    final size = _octal(header, 124, 12);
    final type = String.fromCharCode(header[156]);
    final dataStart = offset + _block;
    if (dataStart + size > bytes.length) {
      throw TarException('the tar stream ends inside a member at $offset');
    }
    final data = Uint8List.sublistView(bytes, dataStart, dataStart + size);
    offset = dataStart + (size + _block - 1) ~/ _block * _block;
    switch (type) {
      case 'x':
        extended = _paxRecords(data);
        continue;
      case 'g':
        continue;
    }
    final name = _string(header, 0, 100);
    final prefix = _string(header, 345, 155);
    final path = extended['path'] ?? (prefix.isEmpty ? name : '$prefix/$name');
    final linkTarget = extended['linkpath'] ?? _string(header, 157, 100);
    extended = const {};
    final memberType = switch (type) {
      '0' || '\x00' || '7' => TarMemberType.file,
      '2' => TarMemberType.symlink,
      '5' => TarMemberType.directory,
      _ => throw TarException('$path: tar member type "$type" is not read'),
    };
    members.add((
      path: path,
      type: memberType,
      mode: _octal(header, 100, 8),
      bytes: data,
      linkTarget: linkTarget,
    ));
  }
  return members;
}

void _requireChecksum(Uint8List header, int offset) {
  var sum = 0;
  for (var index = 0; index < _block; index++) {
    sum += index >= 148 && index < 156 ? 0x20 : header[index];
  }
  if (sum != _octal(header, 148, 8)) {
    throw TarException('the tar header at $offset has a wrong checksum');
  }
}

int _octal(Uint8List header, int offset, int length) {
  final text = ascii
      .decode(header.sublist(offset, offset + length), allowInvalid: true)
      .replaceAll('\x00', ' ')
      .trim();
  return text.isEmpty ? 0 : int.parse(text, radix: 8);
}

String _string(Uint8List header, int offset, int length) {
  final field = header.sublist(offset, offset + length);
  final end = field.indexOf(0);
  return utf8.decode(end < 0 ? field : field.sublist(0, end));
}

/// The `key=value` records of a pax extended header's [data].
Map<String, String> _paxRecords(Uint8List data) {
  final records = <String, String>{};
  var offset = 0;
  while (offset < data.length) {
    final space = data.indexOf(0x20, offset);
    if (space < 0) break;
    final length = int.parse(ascii.decode(data.sublist(offset, space)));
    final record = utf8.decode(data.sublist(space + 1, offset + length - 1));
    final equals = record.indexOf('=');
    records[record.substring(0, equals)] = record.substring(equals + 1);
    offset += length;
  }
  return records;
}

/// [bytes] compressed by `dart:io`'s zlib at level 9, as gzip with no file
/// name and the time 0 in its header, so the same bytes always compress
/// to the same bytes under the same Dart.
List<int> gzipCompress(List<int> bytes) => GZipCodec(level: 9).encode(bytes);

/// The modes of the files each directory [unpackTarGz] unpacked had in
/// their tar headers, by the directory's absolute path, each by its path
/// relative to the directory with `/` between its segments.
///
/// NTFS keeps no executable bit, so on Windows a file's git mode comes
/// from here rather than from the unpacked file.
final unpackedModes = <String, Map<String, int>>{};

/// Unpacks the gzip-compressed tar [archive] into [destination], without
/// the first [stripComponents] segments of each path, and records each
/// file's mode in [unpackedModes].
///
/// A member whose path would lead out of [destination] throws a
/// [TarException], and so does a symbolic link, which Windows creates only
/// with a privilege a build should not need.
Future<void> unpackTarGz(
  String archive,
  String destination, {
  int stripComponents = 0,
}) async {
  final members = readTar(
    Uint8List.fromList(gzip.decode(await File(archive).readAsBytes())),
  );
  final modes = <String, int>{};
  for (final member in members) {
    final segments = member.path
        .split('/')
        .where((s) => s.isNotEmpty && s != '.')
        .skip(stripComponents)
        .toList();
    if (segments.isEmpty) continue;
    final path = p.joinAll([destination, ...segments]);
    if (segments.any(_leavesItsDirectory) || !p.isWithin(destination, path)) {
      throw TarException('$archive: ${member.path} leads out of the archive');
    }
    final relative = segments.join('/');
    switch (member.type) {
      case TarMemberType.directory:
        Directory(path).createSync(recursive: true);
      case TarMemberType.file:
        File(path)
          ..parent.createSync(recursive: true)
          ..writeAsBytesSync(member.bytes);
        modes[relative] = member.mode;
      case TarMemberType.symlink:
        throw TarException(
          '$archive: ${member.path} is a symbolic link, which a build on '
          'Windows does not unpack',
        );
    }
  }
  unpackedModes[p.normalize(p.absolute(destination))] = modes;
}

/// Whether the path segment [segment] of a tar member could lead a joined
/// path out of the directory it is unpacked into: `..`, or, since Windows
/// reads `\` as a separator and `C:` as a drive, any segment holding
/// either, or one the host's path rules read as a root.
bool _leavesItsDirectory(String segment) =>
    segment == '..' ||
    segment.contains(r'\') ||
    segment.contains(':') ||
    p.isAbsolute(segment) ||
    p.rootPrefix(segment).isNotEmpty;

/// The bytes of the file at [path] relative to the top-level directory
/// of the gzip-compressed tar [archive], or null when it holds no such
/// file.
///
/// A source bundle is a tree `git archive` writes under one top-level
/// directory; a release archive has none (see [tarGzRootFile]).
Future<Uint8List?> tarGzFile(String archive, String path) => _tarGzMember(
  archive,
  (member) => member.path.split('/').skip(1).join('/') == path,
);

/// The bytes of the file at [path] in the gzip-compressed tar [archive],
/// named as the archive names it, or null when it holds no such file.
///
/// A release archive holds its files at the root, `build_info.json` and
/// `dylibs/<language>/...` with no top-level directory, so no path segment
/// is skipped.
Future<Uint8List?> tarGzRootFile(String archive, String path) =>
    _tarGzMember(archive, (member) => member.path == path);

Future<Uint8List?> _tarGzMember(
  String archive,
  bool Function(TarMember member) matches,
) async {
  final members = readTar(
    Uint8List.fromList(gzip.decode(await File(archive).readAsBytes())),
  );
  for (final member in members) {
    if (member.type == TarMemberType.file && matches(member)) {
      return member.bytes;
    }
  }
  return null;
}

/// Whether a build on [operatingSystem], by default the one this process
/// runs on, as `Platform.operatingSystem` spells it, computes sha256
/// digests in Dart rather than with `/usr/bin/shasum`: everywhere but
/// macOS, which always has shasum. Windows has none at a fixed path, and a
/// minimal Linux image none at all, since it comes with Perl.
bool sha256InDart([String? operatingSystem]) =>
    (operatingSystem ?? Platform.operatingSystem) != 'macos';

/// The `shasum` a build on macOS runs to compute a sha256 digest. Tests
/// name a file that does not exist, to show that a build elsewhere never
/// runs it.
String shasumExecutable = '/usr/bin/shasum';

/// The sha256 of the file at [path], in lowercase hex, computed in Dart,
/// where a build on macOS runs `/usr/bin/shasum`.
Future<String> dartFileSha256(String path) async =>
    (await crypto.sha256.bind(File(path).openRead()).single).toString();

/// The sha256 of [bytes], in lowercase hex.
String dartSha256(List<int> bytes) => crypto.sha256.convert(bytes).toString();
