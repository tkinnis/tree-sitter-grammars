/// Decodes a gzip file (RFC 1952) holding exactly one member, checking all
/// of it: its header, its deflate stream (RFC 1951) to its last block, and
/// the CRC-32 and length its trailer records, with no byte after it.
///
/// `dart:io`'s `gzip.decode` checks none of the ends: a stream cut short,
/// inside its deflate data or its trailer, decodes to what it holds so far
/// without an error, and a second member, or a byte after the first, is
/// decoded too or ignored. zlib, beneath it, does not say how much of its
/// input the deflate stream took, so nothing it returns tells where the
/// trailer is. The deflate stream is decoded here instead, which tells
/// exactly where it ends: the trailer is the 8 bytes after it, and the file
/// must end there.
library;

import 'dart:typed_data';

/// The bytes the gzip file [input] holds.
///
/// Throws a [FormatException] saying what is wrong when [input] is not
/// exactly one whole gzip member: a header that is no gzip header, sets a
/// reserved flag or is cut short, or whose CRC-16 is wrong; a deflate
/// stream that is malformed or cut short; a trailer cut short, or whose
/// CRC-32 or length is not the decoded bytes'; and any byte after the
/// trailer, a second member's or any other.
Uint8List gunzip(Uint8List input) {
  final at = _headerEnd(input);
  final inflater = _Inflater(input, at);
  final output = inflater.inflate();
  final end = inflater.end;
  if (input.length - end < 8) {
    throw FormatException(
      'its trailer is cut short: ${input.length - end} of its 8 bytes',
    );
  }
  if (input.length > end + 8) {
    final rest = input.length - end - 8;
    final secondMember =
        input[end + 8] == 0x1f && (rest == 1 || input[end + 9] == 0x8b);
    final follow = rest == 1 ? '1 byte follows' : '$rest bytes follow';
    throw FormatException(
      secondMember
          ? 'a second gzip member follows the first'
          : '$follow its trailer',
    );
  }
  final crc = _uint32(input, end);
  final length = _uint32(input, end + 4);
  if (crc != crc32(output)) {
    throw const FormatException(
      'its trailer records another CRC-32 than the decoded bytes have',
    );
  }
  if (length != output.length & 0xffffffff) {
    throw FormatException(
      'its trailer records a length of $length bytes, and it decodes to '
      '${output.length}',
    );
  }
  return output;
}

int _uint32(Uint8List bytes, int at) =>
    bytes[at] | bytes[at + 1] << 8 | bytes[at + 2] << 16 | bytes[at + 3] << 24;

/// Where the deflate stream of the gzip file [input] starts, past its
/// header and the optional fields its flags say follow it.
int _headerEnd(Uint8List input) {
  FormatException cut() => const FormatException('its header is cut short');
  if (input.length < 2 || input[0] != 0x1f || input[1] != 0x8b) {
    throw const FormatException('it does not start as a gzip file does');
  }
  if (input.length < 10) throw cut();
  if (input[2] != 8) {
    throw FormatException(
      'its compression method is ${input[2]}, not deflate (8)',
    );
  }
  final flags = input[3];
  if (flags & 0xe0 != 0) {
    throw const FormatException('its header sets a reserved flag');
  }
  var at = 10;
  if (flags & 0x04 != 0) {
    // FEXTRA: a two-byte length and that many bytes.
    if (input.length < at + 2) throw cut();
    at += 2 + (input[at] | input[at + 1] << 8);
    if (input.length < at) throw cut();
  }
  for (final flag in const [0x08, 0x10]) {
    // FNAME and FCOMMENT: text ending in a NUL.
    if (flags & flag == 0) continue;
    final nul = input.indexOf(0, at);
    if (nul < 0) throw cut();
    at = nul + 1;
  }
  if (flags & 0x02 != 0) {
    // FHCRC: the low 16 bits of the CRC-32 of the header before it.
    if (input.length < at + 2) throw cut();
    final recorded = input[at] | input[at + 1] << 8;
    if (recorded != crc32(Uint8List.sublistView(input, 0, at)) & 0xffff) {
      throw const FormatException('its header has a wrong CRC-16');
    }
    at += 2;
  }
  return at;
}

final _crcTable = () {
  final table = Uint32List(256);
  for (var n = 0; n < 256; n++) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = c & 1 != 0 ? 0xedb88320 ^ (c >> 1) : c >> 1;
    }
    table[n] = c;
  }
  return table;
}();

/// The CRC-32 of [bytes], as gzip and zlib compute it.
int crc32(List<int> bytes) {
  var crc = 0xffffffff;
  for (final byte in bytes) {
    crc = _crcTable[(crc ^ byte) & 0xff] ^ (crc >> 8);
  }
  return crc ^ 0xffffffff;
}

/// The base lengths and extra bits of the length symbols 257 to 285, and
/// the base distances and extra bits of the distance symbols 0 to 29.
const _lengthBase = [
  3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, //
  67, 83, 99, 115, 131, 163, 195, 227, 258,
];
const _lengthExtra = [
  0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, //
  5, 5, 5, 5, 0,
];
const _distanceBase = [
  1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, //
  769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577,
];
const _distanceExtra = [
  0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, //
  11, 11, 12, 12, 13, 13,
];

/// The order the code length code lengths of a dynamic block come in.
const _codeLengthOrder = [
  16,
  17,
  18,
  0,
  8,
  7,
  9,
  6,
  10,
  5,
  11,
  4,
  12,
  3,
  13,
  2,
  14,
  1,
  15,
];

/// A canonical Huffman code as a table indexed by the next [bits] bits of
/// the stream, least significant first: each entry the symbol shifted left
/// by 4 and the length of its code, or 0 where no code begins with those
/// bits.
final class _Code {
  _Code(this.table, this.bits);

  /// The code whose symbols have the code lengths [lengths], by symbol; a
  /// length of 0 is no code.
  ///
  /// Throws a [FormatException], as zlib's `inflate_table` refuses them,
  /// for lengths no prefix code has and for an incomplete code, one that
  /// leaves some bit pattern unused, unless it is a single code of length
  /// 1 and [codeLengths] is false: zlib allows that of a literal/length or
  /// a distance code, and a code-length code ([codeLengths] true) must be
  /// complete. A code with no code at all is allowed, as zlib allows it,
  /// and a stream that reaches it is refused as it is decoded.
  factory _Code.of(List<int> lengths, {bool codeLengths = false}) {
    final counts = List.filled(16, 0);
    var bits = 0;
    for (final length in lengths) {
      counts[length]++;
      if (length > bits) bits = length;
    }
    counts[0] = 0;
    var left = 1;
    for (var length = 1; length < 16; length++) {
      left = (left << 1) - counts[length];
      if (left < 0) {
        throw const FormatException(
          'its deflate stream has a Huffman code with too many codes',
        );
      }
    }
    if (bits > 0 && left > 0 && (codeLengths || bits != 1)) {
      throw const FormatException(
        'its deflate stream has an incomplete Huffman code',
      );
    }
    final next = List.filled(16, 0);
    for (var length = 1, code = 0; length < 16; length++) {
      code = (code + counts[length - 1]) << 1;
      next[length] = code;
    }
    final table = Int32List(1 << bits);
    for (var symbol = 0; symbol < lengths.length; symbol++) {
      final length = lengths[symbol];
      if (length == 0) continue;
      final code = next[length]++;
      var reversed = 0;
      for (var bit = 0; bit < length; bit++) {
        reversed |= (code >> bit & 1) << (length - 1 - bit);
      }
      final entry = symbol << 4 | length;
      for (var index = reversed; index < table.length; index += 1 << length) {
        table[index] = entry;
      }
    }
    return _Code(table, bits);
  }

  final Int32List table;
  final int bits;
}

final _fixedLengths = _Code.of([
  for (var symbol = 0; symbol < 288; symbol++)
    symbol < 144
        ? 8
        : symbol < 256
        ? 9
        : symbol < 280
        ? 7
        : 8,
]);
// zlib builds the fixed distance code of 32 codes of length 5, a complete
// code, and refuses 30 and 31 as they are decoded, as _huffman does.
final _fixedDistances = _Code.of(List.filled(32, 5));

/// Decodes the deflate stream of [_input] that starts at [_position].
final class _Inflater {
  _Inflater(this._input, this._position);

  final Uint8List _input;

  /// The next byte of [_input] to read into [_bits].
  int _position;

  /// Bits read from [_input] and not yet used, the next in the lowest bit,
  /// and how many there are.
  int _bits = 0;
  int _count = 0;

  var _output = Uint8List(1 << 16);
  int _length = 0;

  /// Where the deflate stream ends in [_input], once [inflate] returns: the
  /// byte after the one that holds its last bit.
  int get end => _position - (_count >> 3);

  static const _cutShort = FormatException('its deflate stream is cut short');

  /// The decoded bytes of every block, to the last.
  Uint8List inflate() {
    while (true) {
      final last = _take(1);
      switch (_take(2)) {
        case 0:
          _stored();
        case 1:
          _huffman(_fixedLengths, _fixedDistances);
        case 2:
          final (lengths, distances) = _dynamicCodes();
          _huffman(lengths, distances);
        default:
          throw const FormatException(
            'its deflate stream has a block of the reserved type 3',
          );
      }
      if (last == 1) break;
    }
    return Uint8List.sublistView(_output, 0, _length);
  }

  /// Reads bytes into [_bits] until it holds [count] bits, or as many as
  /// the input has.
  void _fill(int count) {
    while (_count < count && _position < _input.length) {
      _bits |= _input[_position++] << _count;
      _count += 8;
    }
  }

  /// The next [count] bits, the first in the lowest bit.
  int _take(int count) {
    if (count == 0) return 0;
    _fill(count);
    if (_count < count) throw _cutShort;
    final value = _bits & ((1 << count) - 1);
    _bits >>= count;
    _count -= count;
    return value;
  }

  /// The next symbol of [code].
  int _symbol(_Code code) {
    _fill(code.bits);
    final entry = code.table[_bits & ((1 << code.bits) - 1)];
    final length = entry & 0xf;
    if (length == 0) {
      // Past the input, the missing bits read as 0, and may land on no
      // code, as a stream cut short does.
      if (_count < code.bits) throw _cutShort;
      throw const FormatException(
        'its deflate stream has a code its Huffman code does not define',
      );
    }
    if (length > _count) throw _cutShort;
    _bits >>= length;
    _count -= length;
    return entry >> 4;
  }

  void _reserve(int count) {
    if (_length + count <= _output.length) return;
    var size = _output.length * 2;
    while (size < _length + count) {
      size *= 2;
    }
    _output = Uint8List(size)..setRange(0, _length, _output);
  }

  void _stored() {
    // A stored block starts at a byte: the bits left of this one are
    // padding, and the bytes [_bits] holds past it are read again.
    _position -= _count >> 3;
    _bits = 0;
    _count = 0;
    if (_input.length - _position < 4) throw _cutShort;
    final length = _input[_position] | _input[_position + 1] << 8;
    final complement = _input[_position + 2] | _input[_position + 3] << 8;
    if (length != complement ^ 0xffff) {
      throw const FormatException(
        'its deflate stream has a stored block whose length and its '
        'complement differ',
      );
    }
    _position += 4;
    if (_input.length - _position < length) throw _cutShort;
    _reserve(length);
    _output.setRange(_length, _length + length, _input, _position);
    _length += length;
    _position += length;
  }

  (_Code, _Code) _dynamicCodes() {
    final lengthCount = _take(5) + 257;
    final distanceCount = _take(5) + 1;
    final codeLengthCount = _take(4) + 4;
    if (lengthCount > 286 || distanceCount > 30) {
      throw const FormatException(
        'its deflate stream has a dynamic block with too many length or '
        'distance codes',
      );
    }
    final codeLengths = List.filled(19, 0);
    for (var index = 0; index < codeLengthCount; index++) {
      codeLengths[_codeLengthOrder[index]] = _take(3);
    }
    final codeLengthCode = _Code.of(codeLengths, codeLengths: true);
    final lengths = <int>[];
    final total = lengthCount + distanceCount;
    while (lengths.length < total) {
      final symbol = _symbol(codeLengthCode);
      final int value;
      final int repeat;
      switch (symbol) {
        case < 16:
          value = symbol;
          repeat = 1;
        case 16:
          if (lengths.isEmpty) {
            throw const FormatException(
              'its deflate stream repeats a code length before the first',
            );
          }
          value = lengths.last;
          repeat = 3 + _take(2);
        case 17:
          value = 0;
          repeat = 3 + _take(3);
        default:
          value = 0;
          repeat = 11 + _take(7);
      }
      if (lengths.length + repeat > total) {
        throw const FormatException(
          'its deflate stream repeats a code length past the last code',
        );
      }
      lengths.addAll(List.filled(repeat, value));
    }
    if (lengths[256] == 0) {
      throw const FormatException(
        'its deflate stream has a dynamic block with no end-of-block code',
      );
    }
    return (
      _Code.of(lengths.sublist(0, lengthCount)),
      _Code.of(lengths.sublist(lengthCount)),
    );
  }

  void _huffman(_Code lengths, _Code distances) {
    while (true) {
      final symbol = _symbol(lengths);
      if (symbol < 256) {
        _reserve(1);
        _output[_length++] = symbol;
        continue;
      }
      if (symbol == 256) return;
      final index = symbol - 257;
      if (index >= 29) {
        throw FormatException(
          'its deflate stream has the invalid length symbol $symbol',
        );
      }
      final length = _lengthBase[index] + _take(_lengthExtra[index]);
      final distanceSymbol = _symbol(distances);
      if (distanceSymbol >= 30) {
        throw FormatException(
          'its deflate stream has the invalid distance symbol '
          '$distanceSymbol',
        );
      }
      final distance =
          _distanceBase[distanceSymbol] + _take(_distanceExtra[distanceSymbol]);
      if (distance > _length) {
        throw const FormatException(
          'its deflate stream refers to a byte before the first',
        );
      }
      _reserve(length);
      final from = _length - distance;
      if (distance >= length) {
        _output.setRange(_length, _length + length, _output, from);
      } else {
        for (var offset = 0; offset < length; offset++) {
          _output[_length + offset] = _output[from + offset];
        }
      }
      _length += length;
    }
  }
}
