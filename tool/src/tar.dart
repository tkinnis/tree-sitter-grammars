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

import 'gunzip.dart';

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
enum TarMemberType {
  file('file'),
  symlink('symbolic link'),
  directory('directory');

  const TarMemberType(this.label);

  /// The member type as a message names it.
  final String label;
}

const _block = 512;

/// [files], in their order, as a ustar stream: each file owned by
/// `root:wheel` (uid and gid 0) with its own mode and time, no directory
/// entries, and the two zero blocks that end the stream.
///
/// A path longer than the 100 bytes of a header's name field is split at
/// a `/` into its 155-byte prefix field, as ustar defines; one that fits
/// neither way throws a [TarException]. So, on every host, so that an
/// archive this writes unpacks on Windows as [unpackTarGz] unpacks it, does
/// a path [_MemberRules] refuses: one that is absolute or has an empty, `.`
/// or `..` segment, one with a segment Windows cannot name a file by (see
/// [windowsNameProblem]) or that holds a character outside printable ASCII
/// (see [_asciiProblem]), and one that cannot be unpacked with the paths
/// before it (see [_Layout]).
Uint8List ustar(List<TarFile> files) {
  final stream = BytesBuilder(copy: false);
  final rules = _MemberRules.written();
  for (final file in files) {
    rules.check(file.path, TarMemberType.file);
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
/// whose checksum is wrong, for a member of any other type, and for a
/// stream that is malformed anywhere: a numeric field that is no octal
/// number, a name that is no UTF-8, a pax record that does not fit its
/// header or holds no `key=value`, and a stream that ends inside a member
/// or a header or without the zero block that ends an archive, as one cut
/// short does.
///
/// It also throws for a stream GNU tar or bsdtar would read otherwise, so
/// that what is checked here is what tar unpacks: a pax record other than
/// those [_paxKeys] and [_globalPaxKeys] name, and an extended header
/// after another, with no member between them; and a directory or a
/// symbolic link whose header gives it data, which neither tar reads after
/// a directory and only GNU tar skips after a link; and a header without
/// the ustar magic, as an old GNU or a v7 header is, whose bytes 345 to 499
/// both tars read as no prefix of its path.
List<TarMember> readTar(Uint8List bytes) {
  final members = <TarMember>[];
  var offset = 0;
  Map<String, String> extended = const {};
  // Where the extended header the next member takes its records from is,
  // or null when there is none.
  int? extendedAt;
  while (true) {
    if (offset + _block > bytes.length) {
      // A stream cut short at a member's end would otherwise read as
      // whole, with the members past the cut missing.
      throw TarException(
        'the tar stream ends at $offset without the zero block that ends '
        'an archive',
      );
    }
    final at = offset;
    final header = Uint8List.sublistView(bytes, at, at + _block);
    if (header.every((byte) => byte == 0)) break;
    _requireChecksum(header, offset);
    // GNU tar and bsdtar read bytes 345 to 499 as the prefix of a path only
    // after this magic: an old GNU header holds times there.
    if (!_startsWith(header, 257, _ustarMagic)) {
      final magic = latin1.decode(header.sublist(257, 265));
      throw TarException(
        'the tar header at $at is no ustar header: its magic is '
        '${jsonEncode(magic)}',
      );
    }
    final size = _octal(header, 124, 12, 'size', offset);
    final type = String.fromCharCode(header[156]);
    final dataStart = offset + _block;
    if (size > bytes.length - dataStart) {
      throw TarException('the tar stream ends inside a member at $offset');
    }
    final data = Uint8List.sublistView(bytes, dataStart, dataStart + size);
    offset = dataStart + (size + _block - 1) ~/ _block * _block;
    if (type == 'x' || type == 'g') {
      if (extendedAt != null) {
        throw TarException(
          'the pax header at $at follows the extended header at '
          '$extendedAt, with no member between them',
        );
      }
      final records = _paxRecords(data, at);
      final global = type == 'g';
      for (final key in records.keys) {
        if (!(global ? _globalPaxKeys : _paxKeys).contains(key)) {
          throw TarException(
            'the pax ${global ? 'global ' : ''}header at $at holds a '
            '"$key" record, which tar reads and this reader does not',
          );
        }
      }
      if (!global) {
        extended = records;
        extendedAt = at;
      }
      continue;
    }
    extendedAt = null;
    final name = _string(header, 0, 100, 'name', at);
    final prefix = _string(header, 345, 155, 'prefix', at);
    final path = extended['path'] ?? (prefix.isEmpty ? name : '$prefix/$name');
    final linkTarget =
        extended['linkpath'] ?? _string(header, 157, 100, 'link name', at);
    extended = const {};
    final memberType = switch (type) {
      '0' || '\x00' || '7' => TarMemberType.file,
      '2' => TarMemberType.symlink,
      '5' => TarMemberType.directory,
      _ => throw TarException('$path: tar member type "$type" is not read'),
    };
    if (memberType != TarMemberType.file && size != 0) {
      // GNU tar and bsdtar read no data after a directory, and only GNU
      // tar skips the data a symbolic link's header gives, so the header
      // after it is another for each.
      throw TarException(
        'the tar header at $at gives the ${memberType.label} $path $size '
        'bytes of data',
      );
    }
    members.add((
      path: path,
      type: memberType,
      mode: _octal(header, 100, 8, 'mode', at),
      bytes: data,
      linkTarget: linkTarget,
    ));
  }
  return members;
}

/// The records of a pax extended header (`x`) [readTar] reads, the path
/// and link target of the member after it, or leaves aside as saying
/// nothing of where a member is unpacked or what it holds: its times and
/// owners, and a comment.
///
/// GNU tar and bsdtar read more, and a record [readTar] ignored could
/// have a tar read another member than it read: `size` puts the next
/// header elsewhere, and `GNU.sparse.name` renames a member. Any record
/// but these is refused. No archive the build writes or reads holds any:
/// `git archive` writes `path` and `linkpath`, and the release archives
/// are written as plain ustar.
const _paxKeys = {
  'path',
  'linkpath',
  'mtime',
  'atime',
  'ctime',
  'uid',
  'gid',
  'uname',
  'gname',
  'comment',
};

/// The records of a pax global header (`g`) [readTar] leaves aside, as
/// [_paxKeys] does: those of [_paxKeys] that say nothing of where a member
/// is unpacked or what it holds. GNU tar applies a global header's `path`
/// to the members after it, where bsdtar ignores it, so it is refused.
/// `git archive` writes a `comment` naming its commit.
const _globalPaxKeys = {
  'mtime',
  'atime',
  'ctime',
  'uid',
  'gid',
  'uname',
  'gname',
  'comment',
};

/// The magic a ustar or pax header holds at byte 257, `ustar` and a NUL.
const _ustarMagic = [0x75, 0x73, 0x74, 0x61, 0x72, 0x00];

/// Whether [bytes] holds [expected] at [start].
bool _startsWith(Uint8List bytes, int start, List<int> expected) {
  for (var index = 0; index < expected.length; index++) {
    if (bytes[start + index] != expected[index]) return false;
  }
  return true;
}

void _requireChecksum(Uint8List header, int offset) {
  var sum = 0;
  for (var index = 0; index < _block; index++) {
    sum += index >= 148 && index < 156 ? 0x20 : header[index];
  }
  if (sum != _octal(header, 148, 8, 'checksum', offset)) {
    throw TarException('the tar header at $offset has a wrong checksum');
  }
}

/// The octal number in the [field] field of [header], which is at
/// [offset] in its stream: digits from 0 to 7, padded with spaces or NULs.
int _octal(Uint8List header, int start, int length, String field, int offset) {
  final text = ascii
      .decode(header.sublist(start, start + length), allowInvalid: true)
      .replaceAll('\x00', ' ')
      .trim();
  if (!RegExp(r'^[0-7]*$').hasMatch(text)) {
    throw TarException(
      'the tar header at $offset has a $field field that is no octal '
      'number',
    );
  }
  return text.isEmpty ? 0 : int.parse(text, radix: 8);
}

/// The NUL-terminated UTF-8 text in the [field] field of [header], which is
/// at [offset] in its stream.
String _string(
  Uint8List header,
  int start,
  int length,
  String field,
  int offset,
) {
  final bytes = header.sublist(start, start + length);
  final end = bytes.indexOf(0);
  try {
    return utf8.decode(end < 0 ? bytes : bytes.sublist(0, end));
  } on FormatException {
    throw TarException(
      'the tar header at $offset has a $field field that is no UTF-8',
    );
  }
}

/// The `key=value` records of the pax extended header at [offset], whose
/// data is [data]: each `<length> <key>=<value>\n`, its length, in decimal,
/// counting the whole record.
Map<String, String> _paxRecords(Uint8List data, int offset) {
  TarException malformed() =>
      TarException('the pax header at $offset holds a malformed record');
  final records = <String, String>{};
  var at = 0;
  while (at < data.length) {
    final space = data.indexOf(0x20, at);
    if (space < 0) throw malformed();
    final digits = ascii.decode(data.sublist(at, space), allowInvalid: true);
    if (!RegExp(r'^[0-9]+$').hasMatch(digits)) throw malformed();
    // Digits past the largest int are no length a record has.
    final length = int.tryParse(digits);
    if (length == null) throw malformed();
    // The length must reach past the space and a newline and stay within
    // the data.
    final end = at + length;
    if (length > data.length - at || end < space + 2) throw malformed();
    if (data[end - 1] != 0x0a) throw malformed();
    final String record;
    try {
      record = utf8.decode(data.sublist(space + 1, end - 1));
    } on FormatException {
      throw malformed();
    }
    final equals = record.indexOf('=');
    if (equals < 1) throw malformed();
    records[record.substring(0, equals)] = record.substring(equals + 1);
    at = end;
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
/// Every member is checked before the first is written, and any failure
/// throws a [TarException]: an archive that cannot be read or is
/// malformed (see [readTar]); a member [_MemberRules] refuses, on every
/// host, as the archive must unpack on Windows; one whose path would lead
/// out of [destination]; and a member the file system will not write,
/// which no check of the archive can foresee, as when [destination] is a
/// file, and which may leave the members before it written.
Future<void> unpackTarGz(
  String archive,
  String destination, {
  int stripComponents = 0,
}) async {
  final unpacked = await _checkedMembers(archive, stripComponents);
  for (final (:member, :segments) in unpacked) {
    final path = p.joinAll([destination, ...segments]);
    if (!p.isWithin(destination, path)) {
      throw TarException('$archive: ${member.path} leads out of the archive');
    }
  }
  final modes = <String, int>{};
  for (final (:member, :segments) in unpacked) {
    final path = p.joinAll([destination, ...segments]);
    try {
      switch (member.type) {
        case TarMemberType.directory:
          Directory(path).createSync(recursive: true);
        case TarMemberType.file:
          File(path)
            ..parent.createSync(recursive: true)
            ..writeAsBytesSync(member.bytes);
          modes[segments.join('/')] = member.mode;
        case TarMemberType.symlink:
          throw StateError('a symbolic link is refused before unpacking');
      }
    } on FileSystemException catch (error) {
      throw TarException(
        '$archive: ${member.path} could not be unpacked: ${_reason(error)}',
      );
    }
  }
  unpackedModes[p.normalize(p.absolute(destination))] = modes;
}

/// Holds every member of the gzip-compressed tar [archive] to
/// [_MemberRules], without the first [stripComponents] segments of each
/// path, as [unpackTarGz] does before it writes anything, but writing
/// nothing: for a host that unpacks or reads the archive with its own tar,
/// so it refuses on every host what a build on Windows refuses.
///
/// Throws a [TarException] as [unpackTarGz] does for an archive that
/// cannot be read or is malformed, or for a member the rules refuse.
Future<void> checkTarGz(String archive, {int stripComponents = 0}) async {
  await _checkedMembers(archive, stripComponents);
}

/// Each member of the gzip-compressed tar [archive], as [_readTarGz] reads
/// it, that [_MemberRules] keeps once the first [stripComponents] segments
/// of each path are stripped, with the segments of its path that remain.
///
/// Throws a [TarException] naming [archive] for the first member the rules
/// refuse, having checked every member before it.
Future<List<({TarMember member, List<String> segments})>> _checkedMembers(
  String archive,
  int stripComponents,
) async {
  final rules = _MemberRules.read(stripComponents: stripComponents);
  final kept = <({TarMember member, List<String> segments})>[];
  for (final member in await _readTarGz(archive)) {
    final List<String>? segments;
    try {
      segments = rules.check(member.path, member.type);
    } on TarException catch (error) {
      throw TarException('$archive: $error');
    }
    if (segments != null) kept.add((member: member, segments: segments));
  }
  return kept;
}

/// The rules every member of an archive is held to, the same wherever an
/// archive is written ([ustar]), unpacked ([unpackTarGz]), checked before
/// another tar unpacks it ([checkTarGz]) or read ([tarGzFile],
/// [tarGzRootFile]), so that what is checked is what is
/// unpacked or read and the rules cannot drift between them.
///
/// A member is refused when a segment of its path leads out of the
/// directory it is unpacked into (see [_leavesItsDirectory]); when Windows
/// cannot name a file by a segment (see [windowsNameProblem]) or a segment
/// holds a character outside printable ASCII (see [_asciiProblem]); when it is
/// a symbolic link, which Windows creates only with a privilege a build
/// should not need, and whose target a reader would have to follow; and
/// when it cannot be unpacked with the members before it (see [_Layout]),
/// which refuses one path twice and so leaves no doubt which of two
/// members a reader sees.
final class _MemberRules {
  /// The rules for an archive [ustar] writes, whose paths are written as
  /// they are given, so a path that would not unpack as written, one that
  /// is absolute or has an empty, `.` or `..` segment, is refused.
  _MemberRules.written() : _written = true, _stripComponents = 0;

  /// The rules for an archive read without the first [stripComponents]
  /// segments of each path, after each empty and `.` segment is dropped,
  /// as tar does: `./x` and `a//b` name `x` and `a/b`.
  _MemberRules.read({int stripComponents = 0})
    : _written = false,
      _stripComponents = stripComponents;

  final bool _written;
  final int _stripComponents;
  final _layout = _Layout();

  /// The segments the member at [path] of [type] is unpacked or read at,
  /// or null for a directory that stripping takes whole, as it takes the
  /// top-level directory of a source bundle, or as `./` names the root. A
  /// path that names nothing but as a directory `.` or `./`, such as the
  /// "" or "/" a pax path= record may give or a file named ".", and a file
  /// that stripping takes whole, which tar would skip, are refused.
  ///
  /// Throws a [TarException] starting with [path] when the member is
  /// refused.
  List<String>? check(String path, TarMemberType type) {
    final List<String> segments;
    if (_written) {
      segments = path.split('/');
      if (segments.any((s) => s.isEmpty || s == '.' || s == '..')) {
        throw TarException(
          '$path: a path with an empty, "." or ".." segment, or that '
          'starts with "/", is not unpacked as written',
        );
      }
    } else {
      segments = [
        for (final segment in path.split('/'))
          if (segment.isNotEmpty && segment != '.') segment,
      ];
      if (segments.isEmpty) {
        // `tar -C dir .` names the directory it packs `./`, which unpacks
        // to the destination itself.
        final root = path == '.' || path == './';
        if (root && type == TarMemberType.directory) return null;
        throw TarException(
          'a member named ${jsonEncode(path)} names no file or directory',
        );
      }
      if (segments.any(_leavesItsDirectory)) {
        throw TarException('$path leads out of the archive');
      }
    }
    for (final segment in segments) {
      if (windowsNameProblem(segment) ?? _asciiProblem(segment)
          case final problem?) {
        throw TarException('$path: $problem');
      }
    }
    if (type == TarMemberType.symlink) {
      throw TarException(
        '$path is a symbolic link, which is neither unpacked nor read',
      );
    }
    final kept = segments.skip(_stripComponents).toList();
    if (kept.isEmpty) {
      if (type == TarMemberType.directory) return null;
      throw TarException(
        '$path is a file outside the top-level directory stripped from '
        'each path',
      );
    }
    final isFile = type == TarMemberType.file;
    if (_layout.add(kept, isFile: isFile) case final problem?) {
      throw TarException('$path: $problem');
    }
    return kept;
  }
}

/// The paths of an archive's members so far, each as its `/`-separated
/// segments, to refuse a member that cannot be unpacked with the members
/// before it, on any host or on Windows, where a name matches another
/// whatever the case of its letters.
///
/// A path names a file or a directory, as its member does, and each path
/// a member is under names a directory. A member is refused when a path it
/// names differs only in case from one an earlier member names, as
/// `readme` from `README`, for Windows would write the one over the other
/// or unpack both into one directory; when it is under a file; when it is
/// a file at a path that names a directory or a file already, for the file
/// system would refuse the one or write it over the other only once the
/// members before it are written. A directory named again, by its own
/// member or as a parent, is one directory everywhere and is allowed.
final class _Layout {
  /// Each path named so far, by its [_foldCase]d spelling: as it was first
  /// spelled, and whether it is a file.
  final _paths = <String, ({String spelling, bool isFile})>{};

  /// Why the member at [segments], a file if [isFile] and otherwise a
  /// directory, cannot be unpacked with the members before it, or null
  /// when it can.
  String? add(List<String> segments, {required bool isFile}) {
    for (var count = 1; count <= segments.length; count++) {
      final path = segments.take(count).join('/');
      final key = _foldCase(path);
      final named = _paths[key];
      final last = count == segments.length;
      if (named != null) {
        if (named.spelling != path) {
          return '${jsonEncode(path)} names the same file as '
              '${jsonEncode(named.spelling)} on Windows, which matches names '
              'whatever their case';
        }
        if (named.isFile) {
          return 'an earlier member makes ${jsonEncode(path)} a file';
        }
        if (last && isFile) {
          return 'an earlier member makes ${jsonEncode(path)} a directory';
        }
      }
      _paths[key] = (spelling: path, isFile: last && isFile);
    }
    return null;
  }
}

/// [path] with each character that has a single uppercase character in
/// its place, as Windows compares names: NTFS maps each UTF-16 unit to its
/// uppercase in its own table, and leaves one with no single uppercase,
/// such as `ß`, as it is.
String _foldCase(String path) => String.fromCharCodes([
  for (final rune in path.runes)
    switch (String.fromCharCode(rune).toUpperCase().runes.toList()) {
      [final upper] => upper,
      _ => rune,
    },
]);

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

/// Why the path segment [segment] of a member is refused for a character
/// outside printable ASCII, U+0020 to U+007E, or null when it holds none.
///
/// A name outside ASCII has more than one spelling a file system may keep
/// apart or not: an acute e composed (NFC) and decomposed (NFD) is two names
/// on NTFS and ext4 and one on APFS, so two members may unpack to one file
/// on one host and two on another, and one name may not be found by the
/// spelling another host gives it. Every name the source bundles and the
/// release archives have held is printable ASCII. DEL, U+007F, which
/// [windowsNameProblem] allows as Windows does, is refused here; the
/// control characters below U+0020 are refused there first.
String? _asciiProblem(String segment) {
  for (final rune in segment.runes) {
    if (rune >= 0x20 && rune <= 0x7e) continue;
    final code = rune.toRadixString(16).padLeft(4, '0').toUpperCase();
    return '${jsonEncode(segment)} holds U+$code, outside printable ASCII '
        "(U+0020 to U+007E), which a member's name must keep to";
  }
  return null;
}

/// The names Windows reserves for devices, whatever their case and
/// extension: `NUL.txt` and `nul.tar.gz` name the device `NUL`, as `NUL`
/// does. `COM` and `LPT` take a digit, or a superscript 1, 2 or 3 (U+00B9,
/// U+00B2, U+00B3), which Windows counts as digits there; `CONIN$` and
/// `CONOUT$` name the console's input and output.
final _reservedName = () {
  final digits = '0-9${String.fromCharCodes(const [0xb9, 0xb2, 0xb3])}';
  return RegExp(
    '^(CON|PRN|AUX|NUL|CONIN\\\$|CONOUT\\\$|COM[$digits]|LPT[$digits])\$',
  );
}();

/// Why Windows cannot name a file or directory [segment], one segment of
/// a path, or null when it can: it holds a control character (U+0000 to
/// U+001F) or one of `<>:"/\|?*`, ends in a dot or a space, which Windows
/// strips, so the file it writes has another name, or is a device name
/// (see [_reservedName]), so that Windows opens the device rather than
/// writing a file.
///
/// `.` and `..` are not file names, and are left to the caller.
String? windowsNameProblem(String segment) {
  if (segment == '.' || segment == '..') return null;
  final name = jsonEncode(segment);
  for (final rune in segment.runes) {
    if (rune < 0x20) {
      final code = rune.toRadixString(16).padLeft(4, '0').toUpperCase();
      return '$name holds the control character U+$code, which Windows '
          'does not allow in a name';
    }
    final character = String.fromCharCode(rune);
    if (r'<>:"/\|?*'.contains(character)) {
      return '$name holds ${jsonEncode(character)}, which Windows does not '
          'allow in a name';
    }
  }
  if (segment.endsWith('.') || segment.endsWith(' ')) {
    final end = segment.endsWith('.') ? 'dot' : 'space';
    return '$name ends in a $end, which Windows strips from a name';
  }
  // Windows reads a device name before the first dot, ignoring the spaces
  // that end it: `NUL .txt` is NUL.
  final base = segment.split('.').first.trimRight().toUpperCase();
  if (_reservedName.hasMatch(base)) {
    return '$name names the Windows device $base';
  }
  return null;
}

/// The bytes of the file at [path] relative to the top-level directory
/// of the gzip-compressed tar [archive], or null when it holds no such
/// file.
///
/// A source bundle is a tree `git archive` writes under one top-level
/// directory; a release archive has none (see [tarGzRootFile]). Every
/// member is held to [_MemberRules] first, as [unpackTarGz] holds it, so
/// an archive naming one path twice, as `./x` and `x` or under two
/// top-level directories, is refused rather than read at either member.
Future<Uint8List?> tarGzFile(String archive, String path) =>
    _tarGzMember(archive, path, stripComponents: 1);

/// The bytes of the file at [path] in the gzip-compressed tar [archive],
/// named as the archive names it, after any `./`, or null when it holds no
/// such file.
///
/// A release archive holds its files at the root, `build_info.json` and
/// `dylibs/<language>/...` with no top-level directory, so no path segment
/// is skipped. Every member is held to [_MemberRules] first, as
/// [tarGzFile] holds it.
Future<Uint8List?> tarGzRootFile(String archive, String path) =>
    _tarGzMember(archive, path, stripComponents: 0);

Future<Uint8List?> _tarGzMember(
  String archive,
  String path, {
  required int stripComponents,
}) async {
  for (final (:member, :segments) in await _checkedMembers(
    archive,
    stripComponents,
  )) {
    if (member.type == TarMemberType.file && segments.join('/') == path) {
      return member.bytes;
    }
  }
  return null;
}

/// Every member of the gzip-compressed tar [archive], as [readTar] reads
/// them.
///
/// Throws a [TarException] naming [archive] when it cannot be read, is not
/// exactly one whole gzip member, which [gunzip] checks to the last byte of
/// its trailer, or holds a malformed tar stream.
Future<List<TarMember>> _readTarGz(String archive) async {
  final Uint8List compressed;
  try {
    compressed = await File(archive).readAsBytes();
  } on FileSystemException catch (error) {
    throw TarException('$archive could not be read: ${_reason(error)}');
  }
  final Uint8List stream;
  try {
    stream = gunzip(compressed);
  } on FormatException catch (error) {
    throw TarException('$archive is no gzip stream: ${error.message}');
  }
  try {
    return readTar(stream);
  } on TarException catch (error) {
    throw TarException('$archive: $error');
  }
}

/// What [error] says, with the operating system's own words when it has
/// them.
String _reason(FileSystemException error) => [
  error.message,
  if (error.osError case final osError?) osError.message,
].where((part) => part.isNotEmpty).join(': ');

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
