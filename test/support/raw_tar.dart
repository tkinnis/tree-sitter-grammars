/// Tar streams written header by header, as `ustar` would refuse to write
/// some of the members the tests need.
library;

import 'dart:convert';
import 'dart:typed_data';

/// A ustar header of [type] for a member [name] of [size] bytes, with
/// [edit] made to it before its checksum is computed.
Uint8List rawHeader(
  String name,
  String type,
  int size, {
  void Function(Uint8List header)? edit,
}) {
  final header = Uint8List(512);
  header.setAll(0, utf8.encode(name));
  header.setAll(100, ascii.encode('0000644\x00'));
  header.setAll(
    124,
    ascii.encode('${size.toRadixString(8).padLeft(11, '0')}\x00'),
  );
  header[156] = type.codeUnitAt(0);
  header.setAll(257, ascii.encode('ustar\x0000'));
  edit?.call(header);
  header.setAll(148, ascii.encode(' ' * 8));
  final sum = header.fold<int>(0, (a, b) => a + b);
  header.setAll(
    148,
    ascii.encode('${sum.toRadixString(8).padLeft(6, '0')}\x00 '),
  );
  return header;
}

/// A tar stream of an empty file at each of [paths], written header by
/// header, as ustar would not write some of them, and ended as an archive
/// is.
Uint8List rawStream(List<String> paths) => Uint8List.fromList([
  for (final path in paths) ...rawHeader(path, '0', 0),
  ...Uint8List(1024),
]);

/// A tar stream of [members], written header by header and ended as an
/// archive is: a directory for each that ends in `/`, and otherwise an
/// empty file.
Uint8List rawMembers(List<String> members) => Uint8List.fromList([
  for (final member in members)
    ...rawHeader(member, member.endsWith('/') ? '5' : '0', 0),
  ...Uint8List(1024),
]);
