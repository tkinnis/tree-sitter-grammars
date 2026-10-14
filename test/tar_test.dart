import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../tool/src/gunzip.dart';
import '../tool/src/tar.dart';
import 'support/raw_tar.dart';

/// 2026-01-01T00:00:00Z.
const _epoch = 1767225600;

void main() {
  late String scratch;

  setUp(() => scratch = Directory.systemTemp.createTempSync('tar_test').path);
  tearDown(() => Directory(scratch).deleteSync(recursive: true));

  test('reads back what it writes, modes, times and owners included', () {
    final stream = ustar([
      (path: 'a/x.dll', bytes: [1, 2, 3], mode: 0x1ed, epoch: _epoch),
      (path: 'a/b.scm', bytes: utf8.encode('(a) @b'), mode: 0x1a4, epoch: 0),
    ]);

    final members = readTar(stream);

    check(members.map((m) => m.path)).deepEquals(['a/x.dll', 'a/b.scm']);
    check(members.map((m) => m.mode)).deepEquals([0x1ed, 0x1a4]);
    check(members.first.bytes).deepEquals([1, 2, 3]);
    check(stream.length % 512).equals(0);
    final header = stream.sublist(0, 512);
    check(ascii.decode(header.sublist(257, 262))).equals('ustar');
    check(ascii.decode(header.sublist(265, 269))).equals('root');
    check(ascii.decode(header.sublist(297, 302))).equals('wheel');
    check(
      int.parse(ascii.decode(header.sublist(136, 147)), radix: 8),
    ).equals(_epoch);
  });

  test('splits a long path into the ustar prefix', () {
    final path = '${'d' * 90}/${'e' * 90}/file.scm';

    final members = readTar(
      ustar([(path: path, bytes: const [], mode: 0x1a4, epoch: 0)]),
    );

    check(members.single.path).equals(path);
  });

  test('refuses a path no ustar header holds', () {
    check(
      () => ustar([(path: 'x' * 101, bytes: const [], mode: 0x1a4, epoch: 0)]),
    ).throws<TarException>();
  });

  test('reads the pax path git archive writes for a long path', () {
    final path = 'repo/${'q' * 120}.c';
    final record = ' path=$path\n';
    // A pax record's length counts its own digits.
    var length = record.length + 1;
    length = '$length$record'.length;
    final pax = Uint8List.fromList(utf8.encode('$length$record'));
    final stream = BytesBuilder()
      ..add(rawHeader('pax', 'x', pax.length))
      ..add(pax)
      ..add(Uint8List(512 - pax.length))
      ..add(rawHeader('short', '0', 0))
      ..add(Uint8List(1024));

    check(readTar(stream.takeBytes()).single.path).equals(path);
  });

  test('a header with a wrong checksum is refused', () {
    final stream = ustar([(path: 'x', bytes: const [], mode: 0x1a4, epoch: 0)]);
    stream[0] = 0x79;

    check(() => readTar(stream)).throws<TarException>();
  });

  test('compresses the same bytes to the same bytes', () {
    final bytes = utf8.encode('the same text, twice');

    check(gzipCompress(bytes)).deepEquals(gzipCompress(bytes));
    check(gzip.decode(gzipCompress(bytes))).deepEquals(bytes);
  });

  test('unpacks a bundle without its top directory, keeping modes', () async {
    final archive = p.join(scratch, 'x.tar.gz');
    File(archive).writeAsBytesSync(
      gzipCompress(
        ustar([
          (path: 'top/run.sh', bytes: utf8.encode('#!'), mode: 0x1ed, epoch: 0),
          (
            path: 'top/src/a.c',
            bytes: utf8.encode('int a;'),
            mode: 0x1a4,
            epoch: 0,
          ),
        ]),
      ),
    );
    final destination = p.join(scratch, 'out');

    await unpackTarGz(archive, destination, stripComponents: 1);

    check(
      File(p.join(destination, 'src', 'a.c')).readAsStringSync(),
    ).equals('int a;');
    check(
      unpackedModes[p.normalize(p.absolute(destination))],
    ).isNotNull().deepEquals({'run.sh': 0x1ed, 'src/a.c': 0x1a4});
    check(
      await tarGzFile(archive, 'src/a.c'),
    ).isNotNull().deepEquals(utf8.encode('int a;'));
    check(await tarGzFile(archive, 'missing.c')).isNull();
  });

  // Windows reads `\` as a separator and a drive letter as a root, so a
  // member that names either can leave the destination there though no
  // `/`-separated segment of it is `..`. ustar refuses to write such a
  // path, so the archive is written header by header.
  for (final (name, member) in [
    ('through ..', 'top/../../evil'),
    ('through a backslash', r'top/a\..\..\evil'),
    ('through a drive letter', 'top/C:/evil'),
    ('through a drive-relative path', 'top/C:evil'),
    ('through a rooted path', r'top/\evil'),
  ]) {
    test('refuses a member leading out of the destination $name', () async {
      final archive = p.join(scratch, 'x.tar.gz');
      File(archive).writeAsBytesSync(gzipCompress(rawStream([member])));

      await check(
        unpackTarGz(
          archive,
          p.join(scratch, 'out', 'nested'),
          stripComponents: 1,
        ),
      ).throws<TarException>(
        (it) => _message(it).contains('leads out of the archive'),
      );
      check(File(p.join(scratch, 'evil')).existsSync()).isFalse();
      check(File(p.join(scratch, 'out', 'evil')).existsSync()).isFalse();
    });
  }

  group('a malformed tar stream is refused', () {
    /// Requires [readTar] of [stream] to throw a [TarException] whose
    /// message is [message].
    void refused(Uint8List stream, String message) {
      check(
        () => readTar(stream),
      ).throws<TarException>().has((e) => e.message, 'message').equals(message);
    }

    // Reddened by dropping _octal's requirement of octal digits, after
    // which int.parse throws a FormatException, or reads -1 as a size and
    // the member's data as a RangeError.
    for (final (field, offset, length, text) in [
      ('size', 124, 12, '00000000009\x00'),
      ('size', 124, 12, '-0000000001\x00'),
      ('mode', 100, 8, '0000648\x00'),
    ]) {
      test('a $field field of "${text.replaceAll('\x00', '')}"', () {
        final header = rawHeader(
          'x',
          '0',
          0,
          edit: (header) => header.setAll(offset, ascii.encode(text)),
        );
        check(text.length).equals(length);

        refused(
          Uint8List.fromList([...header, ...Uint8List(1024)]),
          'the tar header at 0 has a $field field that is no octal number',
        );
      });
    }

    test('a name that is no UTF-8', () {
      // Reddened by dropping _string's catch of utf8's FormatException.
      final header = rawHeader(
        'x',
        '0',
        0,
        edit: (header) => header.setAll(0, [0x78, 0xff, 0xfe]),
      );

      refused(
        Uint8List.fromList([...header, ...Uint8List(1024)]),
        'the tar header at 0 has a name field that is no UTF-8',
      );
    });

    for (final (problem, record) in [
      // Reddened by dropping _paxRecords' bound on a record's length, which
      // then reads past the data, a RangeError.
      ('a length past its data', '99 path=x\n'),
      // Reddened by the same mutation: the record would end before its
      // space, a RangeError.
      ('a length of nothing', '0 '),
      // Reddened by dropping _paxRecords' requirement of decimal digits,
      // after which int.parse throws a FormatException.
      ('a length that is no number', 'x path=a\n'),
      // Reddened by parsing the length with int.parse, as _paxRecords did,
      // which throws a FormatException for digits past the largest int,
      // 2^63 - 1, as both of these are.
      ('a length of 20 digits', '99999999999999999999 path=x\n'),
      ('a length of 2^63', '9223372036854775808 path=x\n'),
      // Reddened by _paxRecords' stopping, as it did, at a record with no
      // space, after which the record is ignored.
      ('no length', 'path=a'),
      // Reddened by dropping _paxRecords' requirement of a closing newline,
      // after which the record reads as path=a.
      ('no closing newline', '9 path=ab'),
      // Reddened by dropping _paxRecords' requirement of a key before an
      // =, after which substring throws a RangeError.
      ('no key=value', '6 abc\n'),
      // Reddened by dropping _paxRecords' catch of utf8's FormatException.
      ('a value that is no UTF-8', '10 path=\xff\n'),
    ]) {
      test('a pax record with $problem', () {
        // Each character of [record] as one byte.
        final pax = latin1.encode(record);
        final stream = BytesBuilder()
          ..add(rawHeader('pax', 'x', pax.length))
          ..add(pax)
          ..add(Uint8List(512 - pax.length))
          ..add(rawHeader('short', '0', 0))
          ..add(Uint8List(1024));

        refused(
          stream.takeBytes(),
          'the pax header at 0 holds a malformed record',
        );
      });
    }

    // Reddened by readTar's stopping at the end of the stream, as it did,
    // rather than requiring the zero block that ends an archive: a stream
    // cut short at a member's end, or inside a header, read as whole.
    final whole = ustar([
      (path: 'a.c', bytes: [1, 2, 3], mode: 0x1a4, epoch: 0),
      (path: 'b.c', bytes: [4, 5, 6], mode: 0x1a4, epoch: 0),
    ]);
    test('a stream cut short at a member\'s end', () {
      refused(
        Uint8List.sublistView(whole, 0, 1024),
        'the tar stream ends at 1024 without the zero block that ends an '
        'archive',
      );
    });

    test('a stream cut short inside a header', () {
      refused(
        Uint8List.sublistView(whole, 0, 1024 + 100),
        'the tar stream ends at 1024 without the zero block that ends an '
        'archive',
      );
    });
  });

  group('a pax record tar reads and readTar does not is refused', () {
    // readTar read a pax header's path and linkpath records and ignored
    // every other, where GNU tar and bsdtar read more of them: each case
    // here is one both tars, or GNU tar, list otherwise than readTar did,
    // and is reddened by dropping readTar's refusal of a record it does
    // not read (_paxKeys, _globalPaxKeys).
    final link = rawHeader(
      'top/evil',
      '2',
      0,
      edit: (header) => header.setAll(157, ascii.encode('/etc')),
    );
    for (final (problem, stream, message) in [
      (
        // Both tars take the size from the record: top/x is empty, and
        // the header readTar read as its 512 bytes of data is a symbolic
        // link to /etc, which tarGzRootFile returned as top/x's bytes.
        'size, which hides a member in the data the ustar header gives',
        [
          ...paxHeader('x', ['size=0']),
          ...rawHeader('top/x', '0', 512),
          ...link,
        ],
        'the pax header at 0 holds a "size" record, which tar reads and '
            'this reader does not',
      ),
      (
        // Both tars name the member top/X, which differs from top/x only
        // in case, where readTar read top/y.
        'GNU.sparse.name, which renames the member',
        [
          ...rawHeader('top/x', '0', 0),
          ...paxHeader('x', ['GNU.sparse.name=top/X']),
          ...rawHeader('top/y', '0', 0),
        ],
        'the pax header at 512 holds a "GNU.sparse.name" record, which tar '
            'reads and this reader does not',
      ),
      (
        // GNU tar names the member top/x, where bsdtar and readTar read
        // top/y.
        'path in a global header, which GNU tar applies to the members '
            'after it',
        [
          ...paxHeader('g', ['comment=abc', 'path=top/x']),
          ...rawHeader('top/y', '0', 0),
        ],
        'the pax global header at 0 holds a "path" record, which tar reads '
            'and this reader does not',
      ),
    ]) {
      test(problem, () async {
        final bytes = Uint8List.fromList([...stream, ...Uint8List(1024)]);
        _message(
          check(() => readTar(bytes)).throws<TarException>(),
        ).equals(message);
        final archive = p.join(scratch, 'x.tar.gz');
        File(archive).writeAsBytesSync(gzipCompress(bytes));
        for (final strip in [0, 1]) {
          await check(
            checkTarGz(archive, stripComponents: strip),
          ).throws<TarException>(
            (it) => _message(it).equals('$archive: $message'),
          );
        }
        await check(tarGzRootFile(archive, 'top/x')).throws<TarException>();
      });
    }

    test('two extended headers before one member', () {
      // A second header's records would be read with the first's, or in
      // their place, as one tar or another reads them. Reddened by
      // dropping readTar's refusal of an extended header after another.
      final bytes = Uint8List.fromList([
        ...paxHeader('x', ['path=top/x']),
        ...paxHeader('x', ['mtime=0']),
        ...rawHeader('top/y', '0', 0),
        ...Uint8List(1024),
      ]);
      _message(check(() => readTar(bytes)).throws<TarException>()).equals(
        'the pax header at 1024 follows the extended header at 0, with no '
        'member between them',
      );
    });

    test('the control: the records git archive and tar write are read', () {
      // git archive writes a global comment naming the commit, and a path
      // or linkpath where the ustar header holds none; tar writes times
      // and owners.
      final bytes = Uint8List.fromList([
        ...paxHeader('g', ['comment=0123abc']),
        ...paxHeader('x', [
          'path=top/${'q' * 120}.c',
          'mtime=1767225600.5',
          'atime=1767225600',
          'ctime=1767225600',
          'uid=0',
          'gid=0',
          'uname=root',
          'gname=wheel',
          'comment=x',
        ]),
        ...rawHeader('top/short', '0', 0),
        ...Uint8List(1024),
      ]);
      check(readTar(bytes).single.path).equals('top/${'q' * 120}.c');
    });
  });

  group('a header tar reads otherwise than readTar did is refused', () {
    /// Requires readTar of [members], ended as an archive is, to throw a
    /// TarException whose message is [message], and checkTarGz, at either
    /// strip, and tarGzRootFile to refuse it.
    Future<void> refused(List<int> members, String message) async {
      final bytes = Uint8List.fromList([...members, ...Uint8List(1024)]);
      _message(
        check(() => readTar(bytes)).throws<TarException>(),
      ).equals(message);
      final archive = p.join(scratch, 'x.tar.gz');
      File(archive).writeAsBytesSync(gzipCompress(bytes));
      for (final strip in [0, 1]) {
        await check(
          checkTarGz(archive, stripComponents: strip),
        ).throws<TarException>(
          (it) => _message(it).equals('$archive: $message'),
        );
      }
      await check(tarGzRootFile(archive, 'top/x')).throws<TarException>();
    }

    final link = rawHeader(
      'top/evil',
      '2',
      0,
      edit: (header) => header.setAll(157, ascii.encode('/etc')),
    );

    // Each case is reddened by dropping readTar's refusal of a size other
    // than 0 for a member that is no file.
    test('a directory whose header gives it data', () async {
      // GNU tar and bsdtar read no data after a directory's header,
      // whatever size it gives, where readTar skipped that size: the
      // symbolic link to /etc after it was a member to both tars and
      // none to readTar.
      await refused([
        ...rawHeader('top/d/', '5', 512),
        ...link,
      ], 'the tar header at 0 gives the directory top/d/ 512 bytes of data');
    });

    test('a symbolic link whose header gives it data', () async {
      // GNU tar skips the size a symbolic link's header gives, and bsdtar
      // reads a header there: top/x is a member to bsdtar and none to GNU
      // tar.
      await refused([
        ...rawHeader('top/l', '2', 512),
        ...rawHeader('top/x', '0', 0),
      ], 'the tar header at 0 gives the symbolic link top/l 512 bytes of data');
    });

    // readTar read bytes 345 to 499 as the ustar prefix of a header
    // whatever its magic, where GNU tar and bsdtar read them so only after
    // the ustar magic, "ustar\0": an old GNU header (magic "ustar  \0")
    // holds times there, and a v7 header (no magic) nothing. Each case is
    // reddened by dropping readTar's refusal of a header without the
    // ustar magic.
    for (final (kind, magic) in [
      ('an old GNU header', 'ustar  \x00'),
      ('a v7 header', '\x00' * 8),
    ]) {
      test('$kind, whose bytes 345 on tar reads as no prefix', () async {
        // Both tars read top/x twice and keep the second, B, where readTar
        // read top/x and top/top/x, and tarGzRootFile returned A.
        await refused(
          [
            ...rawHeader('top/x', '0', 1),
            ...'A'.codeUnits,
            ...Uint8List(511),
            ...rawHeader(
              'top/x',
              '0',
              1,
              edit: (header) => header
                ..setAll(257, latin1.encode(magic))
                ..setAll(345, ascii.encode('top')),
            ),
            ...'B'.codeUnits,
            ...Uint8List(511),
          ],
          'the tar header at 1024 is no ustar header: its magic is '
          '${jsonEncode(magic)}',
        );
      });
    }

    // GNU tar and bsdtar read a regular file whose name ends in "/" as a
    // directory, where readTar read a file, which unpackTarGz wrote as an
    // empty file d where tar made a directory; and given data, GNU tar
    // skips it and bsdtar reads a header there. Each case is reddened by
    // dropping readTar's refusal of a file whose path ends in "/".
    for (final (type, size) in [('0', 0), ('\x00', 512)]) {
      test('a file of type ${jsonEncode(type)} whose name ends in "/", '
          'given $size bytes', () async {
        await refused(
          [...rawHeader('top/d/', type, size), ...rawHeader('top/x', '0', 0)],
          'top/d/: a file whose name ends in "/", which tar reads as a '
          'directory',
        );
      });
    }

    test('a file whose pax path ends in "/"', () async {
      await refused(
        paxPathMember('top/d/', name: 'top/f'),
        'top/d/: a file whose name ends in "/", which tar reads as a '
        'directory',
      );
    });
  });

  group('an archive that cannot be read is refused', () {
    test('when the file is missing', () async {
      // Reddened by dropping _readTarGz's catch of the FileSystemException
      // reading the file.
      final archive = p.join(scratch, 'missing.tar.gz');

      await check(
        tarGzRootFile(archive, 'build_info.json'),
      ).throws<TarException>(
        (it) => _message(it).startsWith('$archive could not be read: '),
      );
    });

    test('when it is no gzip stream', () async {
      // Reddened by dropping _readTarGz's catch of gzip's FormatException.
      final archive = p.join(scratch, 'x.tar.gz');
      File(archive).writeAsBytesSync(utf8.encode('no gzip stream at all'));

      await check(
        tarGzRootFile(archive, 'build_info.json'),
      ).throws<TarException>(
        (it) => _message(it).startsWith('$archive is no gzip stream: '),
      );
    });

    test('when its gzip stream is cut short inside a tar member', () async {
      // gunzip refuses the gzip stream before readTar sees the tar stream
      // cut short. Reddened by dropping _readTarGz's catch of gunzip's
      // FormatException, which is no TarException and names no archive.
      final archive = p.join(scratch, 'x.tar.gz');
      final whole = gzipCompress(
        ustar([
          for (var index = 0; index < 64; index++)
            (
              path: 'f$index.c',
              bytes: List.generate(4096, (i) => (i * 7919 + index) % 251),
              mode: 0x1a4,
              epoch: 0,
            ),
        ]),
      );
      File(archive).writeAsBytesSync(whole.sublist(0, whole.length ~/ 2));

      await check(tarGzRootFile(archive, 'f63.c')).throws<TarException>(
        (it) => _message(
          it,
        ).equals('$archive is no gzip stream: its deflate stream is cut short'),
      );
    });
  });

  group('a gzip stream that is not one whole member is refused', () {
    // dart:io's gzip.decode, which _readTarGz ran, checks none of a gzip
    // stream's ends: it decodes a stream cut short, in its trailer or its
    // deflate data, to the bytes it holds so far, and a second member or
    // a stray byte after the first without a word. The tar stream here
    // ends in zero blocks, as GNU tar pads an archive to its 10 KiB
    // record, so a cut near the gzip stream's end leaves a tar stream that
    // readTar reads as whole.
    final whole = gzipCompress([
      ...ustar([
        (
          path: 'build_info.json',
          bytes: List.generate(3000, (i) => (i * 7919) % 251),
          mode: 0x1a4,
          epoch: 0,
        ),
      ]),
      ...Uint8List(8192),
    ]);
    // 512 bytes of header, 3072 of data, 1024 that end the archive, 8192
    // of padding.
    const length = 12800;

    /// Requires [tarGzRootFile] of an archive holding [bytes] to throw a
    /// [TarException] saying the archive is no gzip stream, for [reason].
    Future<void> refused(List<int> bytes, String reason) async {
      final archive = p.join(scratch, 'x.tar.gz');
      File(archive).writeAsBytesSync(bytes);
      await check(
        tarGzRootFile(archive, 'build_info.json'),
      ).throws<TarException>(
        (it) => _message(it).equals('$archive is no gzip stream: $reason'),
      );
    }

    test('the control: the whole stream is read', () async {
      final archive = p.join(scratch, 'x.tar.gz');
      File(archive).writeAsBytesSync(whole);

      check(await tarGzRootFile(archive, 'build_info.json')).isNotNull();
    });

    // Reddened by dropping gunzip's requirement of the 8 trailer bytes
    // after the deflate stream. On 05e54e7, gzip.decode read each whole.
    for (var cut = 1; cut <= 8; cut++) {
      test('a trailer cut short by $cut bytes', () async {
        await refused(
          whole.sublist(0, whole.length - cut),
          'its trailer is cut short: ${8 - cut} of its 8 bytes',
        );
      });
    }

    // Reddened by _Inflater's reading the bits past the input as zeros,
    // as _fill does, rather than refusing them. On 05e54e7, gzip.decode
    // returned the bytes decoded so far.
    for (final cut in [1, 16]) {
      test('a deflate stream cut short by $cut bytes', () async {
        await refused(
          whole.sublist(0, whole.length - 8 - cut),
          'its deflate stream is cut short',
        );
      });
    }

    // Reddened by dropping gunzip's refusal of bytes after the trailer.
    // On 05e54e7, gzip.decode decoded a second member after the first,
    // and ignored a byte or two that start none.
    test('a second member', () async {
      await refused([
        ...whole,
        ...whole,
      ], 'a second gzip member follows the first');
    });

    test('a second member cut down to its magic number', () async {
      await refused([
        ...whole,
        0x1f,
        0x8b,
      ], 'a second gzip member follows the first');
    });

    test('a stray byte after the trailer', () async {
      await refused([...whole, 0], '1 byte follows its trailer');
    });

    // Reddened by dropping gunzip's comparison of the trailer's CRC-32, or
    // its length, with the decoded bytes'. zlib, beneath gzip.decode,
    // checks both when the trailer is whole, so 05e54e7 refused these too,
    // as "Filter error, bad data".
    test('a trailer with a wrong CRC-32', () async {
      final bytes = [...whole];
      bytes[bytes.length - 8] ^= 0x01;
      await refused(
        bytes,
        'its trailer records another CRC-32 than the decoded bytes have',
      );
    });

    test('a trailer with a wrong length', () async {
      final bytes = [...whole];
      bytes[bytes.length - 4] ^= 0x01;
      await refused(
        bytes,
        'its trailer records a length of ${length ^ 1} bytes, and it '
        'decodes to $length',
      );
    });
  });

  group('a gzip stream that decodes past its limit is refused', () {
    // gunzip grew its buffer for as long as the stream decoded, and
    // deflate codes 258 bytes in a few bits, so a small archive could
    // decode to more than memory holds. Each case asks for a limit of its
    // own, to refuse a stream without allocating gunzipLimit.
    final bytes = List.generate(100000, (i) => i * 7919 % 251);
    for (final (kind, level) in [
      ('Huffman-coded blocks', 9),
      ('stored blocks', 0),
    ]) {
      final stream = Uint8List.fromList(GZipCodec(level: level).encode(bytes));

      test('of $kind, one byte past its limit', () {
        // Mutation: drop _reserve's refusal of a length past the limit;
        // this reddens.
        check(() => gunzip(stream, limit: bytes.length - 1))
            .throws<FormatException>()
            .has((e) => e.message, 'message')
            .equals(
              'it decodes to more than ${bytes.length - 1} bytes, the '
              'most a .tar.gz the build reads may hold',
            );
      });

      test('the control: of $kind, exactly its limit is read', () {
        // Mutation: refuse a length that reaches the limit; this reddens
        // the stored case, whose last block reserves room to the limit.
        check(gunzip(stream, limit: bytes.length)).deepEquals(bytes);
      });
    }

    test('a limit below the first buffer gunzip allocates', () {
      // Mutation: allocate the first 64 KiB buffer whatever the limit,
      // which _reserve does not grow for a stream that fits it; this
      // reddens.
      check(
            () => gunzip(
              Uint8List.fromList(gzipCompress(utf8.encode('abc'))),
              limit: 2,
            ),
          )
          .throws<FormatException>()
          .has((e) => e.message, 'message')
          .equals(
            'it decodes to more than 2 bytes, the most a .tar.gz the build '
            'reads may hold',
          );
    });

    test('the limit is 1 GiB', () {
      // Fourteen times the 69 MiB the largest real archive decodes to.
      // Mutation: any other gunzipLimit; this reddens.
      check(gunzipLimit).equals(1 << 30);
    });

    test('an archive is read to gunzipLimit', () {
      // Every reader of a .tar.gz reads it to tarGzLimit, which tests
      // lower; it is gunzipLimit unless they do.
      // Mutation: start tarGzLimit at any other value; this reddens.
      check(tarGzLimit).equals(gunzipLimit);
    });

    test('every reader of a .tar.gz reads it to tarGzLimit', () async {
      // An archive of one empty file decodes to 1536 bytes: its header
      // and the two zero blocks that end it.
      // Mutation: decode an archive to another limit than tarGzLimit,
      // gunzip's default or any other; this reddens.
      final archive = p.join(scratch, 'x.tar.gz');
      File(archive).writeAsBytesSync(gzipCompress(rawStream(['top/a.c'])));
      final limit = tarGzLimit;
      addTearDown(() => tarGzLimit = limit);
      tarGzLimit = 1535;
      final message =
          '$archive is no gzip stream: it decodes to more than 1535 bytes, '
          'the most a .tar.gz the build reads may hold';

      await check(
        unpackTarGz(archive, p.join(scratch, 'out'), stripComponents: 1),
      ).throws<TarException>((it) => _message(it).equals(message));
      await check(
        checkTarGz(archive, stripComponents: 1),
      ).throws<TarException>((it) => _message(it).equals(message));
      await check(
        tarGzFile(archive, 'a.c'),
      ).throws<TarException>((it) => _message(it).equals(message));
      await check(
        tarGzRootFile(archive, 'top/a.c'),
      ).throws<TarException>((it) => _message(it).equals(message));

      // The control: exactly its limit is read.
      tarGzLimit = 1536;
      check(await tarGzFile(archive, 'a.c')).isNotNull().isEmpty();
    });
  });

  group('a Huffman code is held to the rules zlib holds it to', () {
    // zlib's inflate_table refuses a code that leaves some bit pattern
    // unused, an incomplete code, unless it is a literal/length or
    // distance code of a single code of length 1, and gunzip refuses it
    // too, so it reads no stream gzip.decode, GNU tar and bsdtar refuse.
    // Each refused case is reddened by dropping _Code.of's refusal of an
    // incomplete code, and each control by refusing every incomplete code.
    // zlib, through gzip.decode, is asked too, and must agree.

    /// The code-length code of these streams: 18 (a run of zero lengths)
    /// as `0`, 1 as `10` and 2 as `11`, a complete code.
    const complete = {18: 1, 1: 2, 2: 2};

    for (final (problem, codeLengths, literals, distances) in [
      (
        'a literal/length code of two codes of length 2, A and the end of '
            'the block',
        complete,
        {65: 2, 256: 2},
        [1],
      ),
      (
        'a distance code of two codes of length 2',
        complete,
        {65: 1, 256: 2, 257: 2},
        [2, 2],
      ),
      (
        'a code-length code leaving one of its four codes of length 2 unused',
        {18: 2, 1: 2, 2: 2},
        {65: 1, 256: 2, 257: 2},
        [1],
      ),
    ]) {
      test('refused: $problem', () {
        final stream = _gzipOfDynamicBlock(
          codeLengths: codeLengths,
          literals: literals,
          distances: distances,
          // A, then the end of the block.
          symbols: [(65, null), (256, null)],
          output: 'A',
        );

        check(() => gzip.decode(stream)).throws<Object>();
        check(() => gunzip(stream, limit: gunzipLimit))
            .throws<FormatException>()
            .has((e) => e.message, 'message')
            .equals('its deflate stream has an incomplete Huffman code');
      });
    }

    for (final (problem, codeLengths, literals, symbols, output) in [
      (
        'a single distance code of length 1',
        complete,
        {65: 1, 256: 2, 257: 2},
        // A, then 3 bytes from 1 back, then the end of the block.
        [(65, null), (257, 0), (256, null)],
        'AAAA',
      ),
      (
        'a single literal/length code of length 1, the end of the block',
        {18: 1, 1: 1},
        {256: 1},
        [(256, null)],
        '',
      ),
    ]) {
      test('the control, read alike: $problem', () {
        final stream = _gzipOfDynamicBlock(
          codeLengths: codeLengths,
          literals: literals,
          distances: [1],
          symbols: symbols,
          output: output,
        );

        check(utf8.decode(gzip.decode(stream))).equals(output);
        check(utf8.decode(gunzip(stream, limit: gunzipLimit))).equals(output);
      });
    }
  });

  group('a gzip stream zlib refuses is refused', () {
    // Each refused stream is asked of zlib, through gzip.decode, too, and
    // must be refused there as well.

    /// [whole] with the FHCRC flag set and a CRC-16 after its header: the
    /// low 16 bits of the CRC-32 of the header, with [flip] xored in.
    Uint8List withHeaderCrc(List<int> whole, {int flip = 0}) {
      final header = [...whole.take(10)];
      header[3] |= 0x02;
      final crc = (crc32(header) & 0xffff) ^ flip;
      return Uint8List.fromList([
        ...header,
        crc & 0xff,
        crc >> 8,
        ...whole.skip(10),
      ]);
    }

    final abc = gzipCompress(utf8.encode('abc'));

    test('the control: a header with its right CRC-16 is read', () {
      final stream = withHeaderCrc(abc);

      check(utf8.decode(gzip.decode(stream))).equals('abc');
      check(utf8.decode(gunzip(stream, limit: gunzipLimit))).equals('abc');
    });

    test('a header with a wrong CRC-16', () {
      // Mutation: skip _headerEnd's comparison of the FHCRC CRC-16 with
      // the header's (if (false)); this reddens.
      final stream = withHeaderCrc(abc, flip: 1);

      check(() => gzip.decode(stream)).throws<Object>();
      check(() => gunzip(stream, limit: gunzipLimit))
          .throws<FormatException>()
          .has((e) => e.message, 'message')
          .equals('its header has a wrong CRC-16');
    });

    test('a dynamic block with no end-of-block code', () {
      // A literal/length code of A and the length symbol 257, a complete
      // code, so no code is the end of the block, which zlib refuses as
      // "invalid code -- missing end-of-block". Mutation: skip
      // _dynamicCodes' refusal of a code length of 0 for symbol 256 (if
      // (false)); this reddens, as the trailer is decoded as more of the
      // block.
      final stream = _gzipOfDynamicBlock(
        codeLengths: {18: 1, 1: 1},
        literals: {65: 1, 257: 1},
        distances: [1],
        symbols: [(65, null)],
        output: 'A',
      );

      check(() => gzip.decode(stream)).throws<Object>();
      check(() => gunzip(stream, limit: gunzipLimit))
          .throws<FormatException>()
          .has((e) => e.message, 'message')
          .equals(
            'its deflate stream has a dynamic block with no end-of-block code',
          );
    });

    for (final distance in [30, 31]) {
      test('the fixed distance symbol $distance, which codes no distance', () {
        // The fixed distance code has 32 codes of length 5, and 30 and 31
        // code no distance: zlib refuses them as "invalid distance code".
        // Mutation: skip _huffman's refusal of a distance symbol of 30 or
        // more (if (false)); this reddens, as a RangeError.
        final stream = _gzipOfFixedBlock([
          // A: 0x30 + 65, in 8 bits.
          (0x30 + 65, 8),
          // The length symbol 257, a length of 3: 1, in 7 bits.
          (1, 7),
          (distance, 5),
          // The end of the block: 0, in 7 bits.
          (0, 7),
        ], output: 'AAAA');

        check(() => gzip.decode(stream)).throws<Object>();
        check(() => gunzip(stream, limit: gunzipLimit))
            .throws<FormatException>()
            .has((e) => e.message, 'message')
            .equals(
              'its deflate stream has the invalid distance symbol $distance',
            );
      });
    }

    test('the control: a fixed block with the distance symbol 0 is '
        'read', () {
      final stream = _gzipOfFixedBlock([
        (0x30 + 65, 8),
        (1, 7),
        (0, 5),
        (0, 7),
      ], output: 'AAAA');

      check(utf8.decode(gzip.decode(stream))).equals('AAAA');
      check(utf8.decode(gunzip(stream, limit: gunzipLimit))).equals('AAAA');
    });
  });

  group('a name outside printable ASCII is refused', () {
    // Each name is one Windows allows, so only the ASCII rule refuses it.
    // "cafe.c" with an acute e is refused in both its Unicode forms, which
    // NTFS and ext4 keep as two names and APFS reads as one: composed
    // (NFC, U+00E9) and decomposed (NFD, e and the combining acute
    // U+0301). DEL, U+007F, is no control character to Windows, and
    // windowsNameProblem allowed it; printable ASCII ends at U+007E.
    for (final (label, name, code) in [
      ('an acute e, composed (NFC)', 'caf\u00e9.c', 'U+00E9'),
      ('an acute e, decomposed (NFD)', 'cafe\u0301.c', 'U+0301'),
      ('DEL', 'x\x7f', 'U+007F'),
      ('a superscript 1 in no device name', 'lpt\u00b9x', 'U+00B9'),
      ('a snowman', 'snow\u2603', 'U+2603'),
      ('a character past the BMP', 'emoji\u{1f600}', 'U+1F600'),
    ]) {
      final problem =
          '${jsonEncode(name)} holds $code, outside printable ASCII (U+0020 '
          'to U+007E), which a member\'s name must keep to';

      // Reddened by dropping _MemberRules' ASCII rule, after which ustar
      // writes the name.
      test('by ustar: $label', () {
        check(
              () => ustar([
                (path: 'dir/$name', bytes: const [], mode: 0x1a4, epoch: 0),
              ]),
            )
            .throws<TarException>()
            .has((e) => e.message, 'message')
            .equals('dir/$name: $problem');
      });

      // Reddened by the same mutation, after which each unpacks or reads
      // the archive.
      test('by unpackTarGz, checkTarGz and tarGzRootFile, writing nothing: '
          '$label', () async {
        final archive = p.join(scratch, 'x.tar.gz');
        File(
          archive,
        ).writeAsBytesSync(gzipCompress(rawStream(['top/a.c', 'top/$name'])));
        final destination = p.join(scratch, 'out');
        final message = '$archive: top/$name: $problem';

        await check(
          unpackTarGz(archive, destination, stripComponents: 1),
        ).throws<TarException>((it) => _message(it).equals(message));
        check(Directory(destination).existsSync()).isFalse();
        await check(
          checkTarGz(archive, stripComponents: 1),
        ).throws<TarException>((it) => _message(it).equals(message));
        await check(
          tarGzRootFile(archive, 'top/a.c'),
        ).throws<TarException>((it) => _message(it).equals(message));
      });
    }
  });

  group('a name Windows cannot give a file', () {
    final superscriptOne = String.fromCharCode(0xb9);
    final superscriptThree = String.fromCharCode(0xb3);
    final refusedNames = [
      'CON', 'prn', 'Aux', 'NUL', 'nul.txt', 'NUL.tar.gz', 'NUL .txt', //
      'COM0', 'COM1', 'com9', 'LPT1', 'lpt9', 'COM$superscriptOne', //
      'lpt$superscriptThree.h', 'CONIN\$', 'conout\$.log', //
      'trailing.', 'trailing ', 'a<b', 'a>b', 'a:b', 'a"b', 'a|b', 'a?b', //
      'a*b', r'a\b', 'a\x01b', 'a\x1fb', 'a\tb',
    ];
    // The control of the cases: names Windows gives files, some close to
    // the refused ones, in printable ASCII, are written and unpacked.
    final allowedNames = [
      'CONSOLE', 'con_x.c', 'nul-x', 'COM10', 'COM', 'LPT', 'auxiliary.h', //
      'x.NUL', 'x.con.c', 'a.b.c', '.hidden', 'COMx', 'a b.c', //
      'a+b=c,d;e[f]g{h}~',
    ];

    for (final name in refusedNames) {
      test('is refused by ustar on every host: ${jsonEncode(name)}', () {
        // Reddened by dropping ustar's check of each segment against
        // windowsNameProblem.
        check(
              () => ustar([
                (path: 'dir/$name', bytes: const [], mode: 0x1a4, epoch: 0),
              ]),
            )
            .throws<TarException>()
            .has((e) => e.message, 'message')
            .contains(jsonEncode(name));
      });
    }

    // A superscript 1, 2 or 3 is outside printable ASCII, so ustar and
    // unpackTarGz refuse such a name for that first, and the device rule
    // is asked here by itself.
    for (final (name, device) in [
      for (final digit in const [0xb9, 0xb2, 0xb3]) ...[
        (
          'COM${String.fromCharCode(digit)}',
          'COM${String.fromCharCode(digit)}',
        ),
        (
          'lpt${String.fromCharCode(digit)}.h',
          'LPT${String.fromCharCode(digit)}',
        ),
      ],
    ]) {
      test('names a device with a superscript digit: ${jsonEncode(name)}', () {
        // Mutation: narrow _reservedName's digits after COM and LPT to
        // [0-9]; this reddens.
        check(
          windowsNameProblem(name),
        ).equals('${jsonEncode(name)} names the Windows device $device');
      });
    }

    test('the control: a superscript 4 names no device', () {
      // Windows counts only the superscript 1, 2 and 3 as digits there.
      check(windowsNameProblem('COM${String.fromCharCode(0x2074)}')).isNull();
    });

    test('is refused by ustar in a directory segment as well', () {
      // Reddened by dropping ustar's check of each segment against
      // windowsNameProblem.
      check(
            () => ustar([
              (
                path: 'dylibs/aux/x.dll',
                bytes: const [],
                mode: 0x1ed,
                epoch: 0,
              ),
            ]),
          )
          .throws<TarException>()
          .has((e) => e.message, 'message')
          .equals('dylibs/aux/x.dll: "aux" names the Windows device AUX');
    });

    test('that Windows does allow is written and unpacked', () async {
      final archive = p.join(scratch, 'x.tar.gz');
      File(archive).writeAsBytesSync(
        gzipCompress(
          ustar([
            for (final name in allowedNames)
              (path: 'top/$name', bytes: const [1], mode: 0x1a4, epoch: 0),
          ]),
        ),
      );
      final destination = p.join(scratch, 'out');

      await unpackTarGz(archive, destination, stripComponents: 1);

      for (final name in allowedNames) {
        check(File(p.join(destination, name)).existsSync()).isTrue();
      }
    });

    // Names whose old unpacking on Windows wrote nothing visible, wrote to
    // a device or threw a FileSystemException, none of which is a
    // TarException; none opens a device a write could reach.
    for (final name in [
      'NUL.txt',
      'trailing.',
      'trailing ',
      'a?b',
      'a*b',
      'aux/x.c',
      'COM$superscriptOne',
      'a\x01b',
    ]) {
      test('is refused by unpackTarGz on every host, writing nothing: '
          '${jsonEncode(name)}', () async {
        // Reddened by dropping unpackTarGz's check of each segment against
        // windowsNameProblem.
        final archive = p.join(scratch, 'x.tar.gz');
        File(
          archive,
        ).writeAsBytesSync(gzipCompress(rawStream(['top/a.c', 'top/$name'])));
        final destination = p.join(scratch, 'out');

        await check(
          unpackTarGz(archive, destination, stripComponents: 1),
        ).throws<TarException>(
          (it) => _message(it).startsWith('$archive: top/$name: '),
        );
        check(File(p.join(destination, 'a.c')).existsSync()).isFalse();
      });
    }
  });

  test('a member refused after another is unpacked writes nothing', () async {
    // Reddened by unpacking each member as soon as it is checked, as
    // unpackTarGz did, rather than checking every member first.
    final archive = p.join(scratch, 'x.tar.gz');
    File(
      archive,
    ).writeAsBytesSync(gzipCompress(rawStream(['top/a.c', 'top/../../evil'])));
    final destination = p.join(scratch, 'out');

    await check(
      unpackTarGz(archive, destination, stripComponents: 1),
    ).throws<TarException>();
    check(File(p.join(destination, 'a.c')).existsSync()).isFalse();
  });

  group('a member whose path names nothing is refused, writing nothing', () {
    // A pax path= record of "", "." or "/." leaves a member no segment once
    // "." and empty segments are dropped, and unpackTarGz skipped it
    // without a word. Reddened by _MemberRules' returning null for such a
    // member, as unpackTarGz's `if (segments.isEmpty) continue;` did. A
    // file named "./" or "/" ends in "/" and is refused before, by
    // readTar, as a file tar reads as a directory.
    for (final path in ['', '.', '/.', './/.']) {
      test('a pax path of ${jsonEncode(path)}', () async {
        final archive = p.join(scratch, 'x.tar.gz');
        File(archive).writeAsBytesSync(
          gzipCompress([
            ...rawHeader('top/a.c', '0', 0),
            ...paxPathMember(path, name: 'top/b.c'),
            ...Uint8List(1024),
          ]),
        );
        final destination = p.join(scratch, 'out');

        await check(
          unpackTarGz(archive, destination, stripComponents: 1),
        ).throws<TarException>(
          (it) => _message(it).equals(
            '$archive: a member named ${jsonEncode(path)} names no file or '
            'directory',
          ),
        );
        check(Directory(destination).existsSync()).isFalse();
        await check(tarGzRootFile(archive, 'top/a.c')).throws<TarException>();
      });
    }

    test('a file the stripped segments take whole', () async {
      // tar --strip-components skips such a file, as unpackTarGz did; a
      // bundle holds every file under its top-level directory. Reddened by
      // _MemberRules' returning null for a file it strips whole, as it
      // does for a directory.
      final archive = p.join(scratch, 'x.tar.gz');
      File(archive).writeAsBytesSync(
        gzipCompress(rawMembers(['top/', 'README', 'top/a.c'])),
      );
      final destination = p.join(scratch, 'out');

      await check(
        unpackTarGz(archive, destination, stripComponents: 1),
      ).throws<TarException>(
        (it) => _message(it).equals(
          '$archive: README is a file outside the top-level directory '
          'stripped from each path',
        ),
      );
      check(Directory(destination).existsSync()).isFalse();
    });
  });

  test('a member the file system will not write is refused', () async {
    // Reddened by dropping unpackTarGz's catch of the FileSystemException
    // writing a member: here a file under a destination that is a file,
    // which no check of the archive's own members can see.
    final archive = p.join(scratch, 'x.tar.gz');
    File(archive).writeAsBytesSync(gzipCompress(rawStream(['top/a'])));
    final destination = p.join(scratch, 'out');
    File(destination).writeAsStringSync('a file, not a directory');

    await check(
      unpackTarGz(archive, destination, stripComponents: 1),
    ).throws<TarException>(
      (it) =>
          _message(it).startsWith('$archive: top/a could not be unpacked: '),
    );
  });

  group('members that cannot all be unpacked are refused, writing '
      'nothing', () {
    // Each case's members, as rawMembers reads them, and the start of the
    // message refusing the last, after `<archive>: `.
    for (final (problem, members, message) in [
      // Reddened by comparing paths with their case, or not comparing them
      // at all, as unpackTarGz did: Windows writes the second over the
      // first.
      (
        'two files differing only in case',
        ['top/README', 'top/readme'],
        'top/readme: "readme" names the same file as "README" on Windows',
      ),
      // Reddened by the same mutation: Windows unpacks both into one
      // directory, which unpackedModes would not know.
      (
        'two directories differing only in case',
        ['top/Src/a.c', 'top/src/b.c'],
        'top/src/b.c: "src" names the same file as "Src" on Windows',
      ),
      (
        'a directory member and a file\'s directory differing only in case',
        ['top/src/', 'top/SRC/a.c'],
        'top/SRC/a.c: "SRC" names the same file as "src" on Windows',
      ),
      (
        'a member under a file differing only in case',
        ['top/a', 'top/A/b'],
        'top/A/b: "A" names the same file as "a" on Windows',
      ),
      // Reddened by dropping the refusal of a member under a path an
      // earlier member makes a file, after which the file system refuses
      // the second only once the first is written.
      (
        'a member under a file',
        ['top/a', 'top/a/b'],
        'top/a/b: an earlier member makes "a" a file',
      ),
      // Reddened by dropping the refusal of a member at the path an earlier
      // member makes a file, after which the file system refuses a
      // directory there only once the file is written, and a second file
      // is written over the first.
      (
        'a directory member where a file is',
        ['top/a', 'top/a/'],
        'top/a/: an earlier member makes "a" a file',
      ),
      (
        'one file twice',
        ['top/a.c', 'top/a.c'],
        'top/a.c: an earlier member makes "a.c" a file',
      ),
      // Reddened by dropping the refusal of a file at a path an earlier
      // member makes a directory, after which the file system refuses it
      // only once the directory is written.
      (
        'a file where a directory is',
        ['top/a/b', 'top/a'],
        'top/a: an earlier member makes "a" a directory',
      ),
      (
        'a file where a directory member is',
        ['top/a/', 'top/a'],
        'top/a: an earlier member makes "a" a directory',
      ),
    ]) {
      test(problem, () async {
        final archive = p.join(scratch, 'x.tar.gz');
        File(archive).writeAsBytesSync(gzipCompress(rawMembers(members)));
        final destination = p.join(scratch, 'out');

        await check(
          unpackTarGz(archive, destination, stripComponents: 1),
        ).throws<TarException>(
          (it) => _message(it).startsWith('$archive: $message'),
        );
        check(Directory(destination).existsSync()).isFalse();
      });
    }

    test('but a directory a file is also under is unpacked', () async {
      // The control of the cases above: a directory named by its own
      // member and as a file's parent, in either order and in one case, is
      // one directory everywhere.
      final archive = p.join(scratch, 'x.tar.gz');
      File(archive).writeAsBytesSync(
        gzipCompress(
          rawMembers([
            'top/',
            'top/src/',
            'top/src/a.c',
            'top/lib/b.c',
            'top/lib/',
            'top/src/',
            'top/Readme.md',
          ]),
        ),
      );
      final destination = p.join(scratch, 'out');

      await unpackTarGz(archive, destination, stripComponents: 1);

      check(File(p.join(destination, 'src', 'a.c')).existsSync()).isTrue();
      check(File(p.join(destination, 'lib', 'b.c')).existsSync()).isTrue();
      check(unpackedModes[p.normalize(p.absolute(destination))])
          .isNotNull()
          .deepEquals({'src/a.c': 0x1a4, 'lib/b.c': 0x1a4, 'Readme.md': 0x1a4});
    });
  });

  group('stripping a path counts its "." segments as tar does', () {
    // GNU tar and bsdtar strip --strip-components segments of a path as
    // written, a "." among them, and drop the "." segments that remain:
    // ./a/B unpacks to a/B. _MemberRules dropped every "." first and
    // placed it at B, so a member that tar unpacked over another, or into
    // one file with another on Windows, passed the check. Each case is
    // reddened by _MemberRules' dropping "." segments before it strips.
    for (final (problem, members, message) in [
      (
        'a/B, from ./a/B, and a/b, which differ only in case',
        ['top/keep', './a/B', 'x/a/b'],
        'x/a/b: "a/b" names the same file as "a/B" on Windows',
      ),
      (
        'one file twice, as ./a/b and x/a/b',
        ['top/keep', './a/b', 'x/a/b'],
        'x/a/b: an earlier member makes "a/b" a file',
      ),
    ]) {
      test('refused: $problem', () async {
        final archive = p.join(scratch, 'x.tar.gz');
        File(archive).writeAsBytesSync(gzipCompress(rawMembers(members)));

        await check(
          checkTarGz(archive, stripComponents: 1),
        ).throws<TarException>(
          (it) => _message(it).startsWith('$archive: $message'),
        );
        await check(tarGzFile(archive, 'keep')).throws<TarException>();
      });
    }

    test('a member under "./" unpacks where tar unpacks it', () async {
      final archive = p.join(scratch, 'x.tar.gz');
      File(archive).writeAsBytesSync(
        gzipCompress(rawMembers(['./', './top/', './top/a/', './top/a/b'])),
      );
      final destination = p.join(scratch, 'out');

      await unpackTarGz(archive, destination, stripComponents: 1);

      check(File(p.join(destination, 'top', 'a', 'b')).existsSync()).isTrue();
      check(await tarGzFile(archive, 'top/a/b')).isNotNull();
    });
  });

  group('a symbolic link is refused on Windows alone', () {
    // A build on Windows unpacks no symbolic link, which Windows creates
    // only with a privilege a build should not need, while one on macOS or
    // Linux keeps a committed link, as tar unpacks it. Each host is named
    // here by the operatingSystem the check takes, so every case runs on
    // any host.

    /// An archive of [members], ended as an archive is.
    String archiveOf(List<List<int>> members) {
      final archive = p.join(scratch, 'x.tar.gz');
      File(archive).writeAsBytesSync(
        gzipCompress([
          for (final member in members) ...member,
          ...Uint8List(1024),
        ]),
      );
      return archive;
    }

    // Platform.operatingSystem spells each host in lower case; a name is
    // matched whatever the case of its letters.
    for (final operatingSystem in ['macos', 'linux', 'MacOS', 'LINUX']) {
      test('on $operatingSystem, a symbolic link passes the check', () async {
        // Mutation: refuse a symbolic link whatever operatingSystem names;
        // this reddens. Mutation: match the name in its own case; this
        // reddens MacOS and LINUX.
        final archive = archiveOf([
          rawHeader('top/src/parser.c', '0', 0),
          rawLink('top/src/alias.c', 'parser.c'),
        ]);

        await checkTarGz(
          archive,
          stripComponents: 1,
          operatingSystem: operatingSystem,
        );
        check(
          await tarGzFile(
            archive,
            'src/parser.c',
            operatingSystem: operatingSystem,
          ),
        ).isNotNull();
        check(
          await tarGzRootFile(
            archive,
            'top/src/parser.c',
            operatingSystem: operatingSystem,
          ),
        ).isNotNull();
      });
    }

    for (final operatingSystem in ['windows', 'Windows', 'WINDOWS']) {
      test('on $operatingSystem, a symbolic link is refused', () async {
        // Mutation: allow a symbolic link whatever operatingSystem names;
        // this reddens. Mutation: match the name in its own case; this
        // reddens Windows and WINDOWS.
        final archive = archiveOf([
          rawHeader('top/src/parser.c', '0', 0),
          rawLink('top/src/alias.c', 'parser.c'),
        ]);
        final message =
            '$archive: top/src/alias.c is a symbolic link, which a build on '
            'Windows neither unpacks nor reads';

        await check(
          checkTarGz(
            archive,
            stripComponents: 1,
            operatingSystem: operatingSystem,
          ),
        ).throws<TarException>((it) => _message(it).equals(message));
        await check(
          tarGzFile(archive, 'src/parser.c', operatingSystem: operatingSystem),
        ).throws<TarException>((it) => _message(it).equals(message));
        await check(
          tarGzRootFile(
            archive,
            'top/src/parser.c',
            operatingSystem: operatingSystem,
          ),
        ).throws<TarException>((it) => _message(it).equals(message));
      });
    }

    // A build runs on macOS, Linux or Windows alone; any other name, one
    // Platform.operatingSystem gives included, is refused rather than taken
    // for a host that keeps a link.
    for (final operatingSystem in ['android', 'ios', 'fuchsia', 'bsd', '']) {
      test('on "$operatingSystem", reading an archive is refused', () async {
        // Mutation: keep a symbolic link on any host but Windows; this
        // reddens.
        final archive = archiveOf([rawHeader('top/src/parser.c', '0', 0)]);
        void refused(Subject<ArgumentError> it) => it
          ..has((e) => e.name, 'name').equals('operatingSystem')
          ..has((e) => e.invalidValue, 'invalidValue').equals(operatingSystem);

        await check(
          checkTarGz(
            archive,
            stripComponents: 1,
            operatingSystem: operatingSystem,
          ),
        ).throws<ArgumentError>(refused);
        await check(
          tarGzFile(archive, 'src/parser.c', operatingSystem: operatingSystem),
        ).throws<ArgumentError>(refused);
        await check(
          tarGzRootFile(
            archive,
            'top/src/parser.c',
            operatingSystem: operatingSystem,
          ),
        ).throws<ArgumentError>(refused);
      });
    }

    test('unpackTarGz, which unpacks on Windows, refuses a symbolic link on '
        'every host', () async {
      // Mutation: allow a symbolic link in unpackTarGz's rules; this
      // reddens, as a StateError.
      final archive = archiveOf([
        rawHeader('top/a.c', '0', 0),
        rawLink('top/alias.c', 'a.c'),
      ]);
      final destination = p.join(scratch, 'out');

      await check(
        unpackTarGz(archive, destination, stripComponents: 1),
      ).throws<TarException>(
        (it) => _message(it).startsWith(
          '$archive: top/alias.c is a symbolic '
          'link',
        ),
      );
      check(File(p.join(destination, 'a.c')).existsSync()).isFalse();
    });

    // On macOS and Linux, a symbolic link is held to every other rule a
    // member is held to.
    for (final (problem, members, message) in [
      (
        'a link Windows cannot name',
        [rawLink('top/aux.c', 'a.c')],
        'top/aux.c: "aux.c" names the Windows device AUX',
      ),
      (
        'a link named outside printable ASCII',
        [rawLink('top/ä.c', 'a.c')],
        'top/ä.c: "ä.c" holds U+00E4, outside printable ASCII',
      ),
      (
        'a link leading out of the archive',
        [rawLink('top/../../evil', '/etc')],
        'top/../../evil leads out of the archive',
      ),
      (
        'a link differing only in case from a file',
        [rawHeader('top/a.c', '0', 0), rawLink('top/A.c', 'b.c')],
        'top/A.c: "A.c" names the same file as "a.c" on Windows',
      ),
      (
        'a link where a file is',
        [rawHeader('top/a.c', '0', 0), rawLink('top/a.c', 'b.c')],
        'top/a.c: an earlier member makes "a.c" a file',
      ),
      // tar writes a member under a link through it, out of the archive
      // when the link names /tmp: a link is a leaf of the tree, as a file
      // is, and _Layout counts it as a file.
      (
        'a file under a link, which tar would write through it',
        [rawLink('top/d', '/tmp'), rawHeader('top/d/x', '0', 0)],
        'top/d/x: an earlier member makes "d" a file',
      ),
      (
        'a link where a directory is',
        [rawHeader('top/d/', '5', 0), rawLink('top/d', '/tmp')],
        'top/d: an earlier member makes "d" a directory',
      ),
    ]) {
      test('on macos, refused: $problem', () async {
        // Mutation: return a symbolic link's segments before the name,
        // ASCII and layout rules where the link is allowed; this reddens
        // each case but the link leading out of the archive, which those
        // rules follow. Mutation: skip the check of a path leading out of
        // the archive for an allowed link; this reddens that case.
        // Mutation: count a link as a directory in _Layout; this reddens
        // the two cases of a link and a directory.
        final archive = archiveOf(members);

        await check(
          checkTarGz(archive, stripComponents: 1, operatingSystem: 'macos'),
        ).throws<TarException>(
          (it) => _message(it).startsWith('$archive: $message'),
        );
      });
    }

    test('on macos, a link whose header gives it data is refused', () async {
      // Mutation: drop readTar's refusal of data after a symbolic link;
      // this reddens, as no Windows-only refusal of the link stands in
      // its place.
      final archive = archiveOf([rawHeader('top/l', '2', 512), Uint8List(512)]);

      await check(
        checkTarGz(archive, stripComponents: 1, operatingSystem: 'macos'),
      ).throws<TarException>(
        (it) => _message(it).equals(
          '$archive: the tar header at 0 gives the symbolic link top/l 512 '
          'bytes of data',
        ),
      );
    });
  });

  group('ustar refuses a path that would not unpack as written', () {
    for (final (problem, paths, message) in [
      // Reddened by ustar's checking each segment only against
      // windowsNameProblem, as it did, which leaves "", "." and ".." to
      // its caller; unpackTarGz refuses a ".." and drops "" and ".".
      for (final (problem, path) in [
        ('a leading ..', '../x'),
        ('a .. inside', 'a/../b'),
        ('a leading /', '/abs/x'),
        ('a . segment', './x'),
        ('an empty segment', 'a//b'),
        ('a trailing /', 'a/'),
      ])
        (problem, [path], '$path: a path with an empty, "." or ".." segment'),
      // Reddened by ustar's not comparing its paths with one another, as
      // it did not: unpackTarGz refuses each of these.
      (
        'two files differing only in case',
        ['dylibs/a.dll', 'dylibs/A.dll'],
        'dylibs/A.dll: "dylibs/A.dll" names the same file as "dylibs/a.dll" '
            'on Windows',
      ),
      (
        'a file under a file',
        ['a', 'a/b'],
        'a/b: an earlier member makes "a" a file',
      ),
      ('one file twice', ['a', 'a'], 'a: an earlier member makes "a" a file'),
    ]) {
      test(problem, () {
        check(
              () => ustar([
                for (final path in paths)
                  (path: path, bytes: const [], mode: 0x1a4, epoch: 0),
              ]),
            )
            .throws<TarException>()
            .has((e) => e.message, 'message')
            .startsWith(message);
      });
    }
  });

  group('reading one file of an archive holds every member to the rules '
      'unpacking does', () {
    // tarGzRootFile and tarGzFile returned the first member of the path
    // they were asked for and checked no member, where GNU tar and bsdtar
    // keep the last of two: a checker reading build_info.json through
    // them and a consumer unpacking the archive could see two different
    // files. Each case is reddened by _tarGzMember's reading the members
    // as _readTarGz returns them, unchecked, as it did.
    for (final (problem, members, message) in [
      (
        'one file twice',
        ['build_info.json', 'build_info.json'],
        'build_info.json: an earlier member makes "build_info.json" a file',
      ),
      (
        'one file twice, once under "./"',
        ['build_info.json', './build_info.json'],
        './build_info.json: an earlier member makes "build_info.json" a '
            'file',
      ),
      (
        'one file twice, first under "./"',
        ['./build_info.json', 'build_info.json'],
        'build_info.json: an earlier member makes "build_info.json" a file',
      ),
      (
        'two files differing only in case',
        ['Build_Info.json', 'build_info.json'],
        'build_info.json: "build_info.json" names the same file as '
            '"Build_Info.json" on Windows',
      ),
      (
        'a name Windows cannot give a file',
        ['build_info.json', 'dylibs/aux/x.dll'],
        'dylibs/aux/x.dll: "aux" names the Windows device AUX',
      ),
      (
        'a member leading out of the archive',
        ['../build_info.json'],
        '../build_info.json leads out of the archive',
      ),
    ]) {
      test('by tarGzRootFile: $problem', () async {
        final archive = p.join(scratch, 'x.tar.gz');
        File(archive).writeAsBytesSync(gzipCompress(rawMembers(members)));

        await check(
          tarGzRootFile(archive, 'build_info.json'),
        ).throws<TarException>(
          (it) => _message(it).startsWith('$archive: $message'),
        );
      });
    }

    test('by tarGzRootFile on Windows: a symbolic link', () async {
      final archive = p.join(scratch, 'x.tar.gz');
      File(archive).writeAsBytesSync(
        gzipCompress([
          ...rawHeader('build_info.json', '0', 0),
          ...rawHeader('link', '2', 0),
          ...Uint8List(1024),
        ]),
      );

      await check(
        tarGzRootFile(archive, 'build_info.json', operatingSystem: 'windows'),
      ).throws<TarException>(
        (it) => _message(it).startsWith('$archive: link is a symbolic link'),
      );
    });

    for (final (problem, members, message) in [
      (
        'one file twice under two top-level directories',
        ['a/src/x.c', 'b/src/x.c'],
        'b/src/x.c: an earlier member makes "src/x.c" a file',
      ),
      (
        'one file twice, once as "top/./"',
        ['top/src/x.c', 'top/./src/x.c'],
        'top/./src/x.c: an earlier member makes "src/x.c" a file',
      ),
    ]) {
      test('by tarGzFile: $problem', () async {
        final archive = p.join(scratch, 'x.tar.gz');
        File(archive).writeAsBytesSync(gzipCompress(rawMembers(members)));

        await check(tarGzFile(archive, 'src/x.c')).throws<TarException>(
          (it) => _message(it).startsWith('$archive: $message'),
        );
      });
    }

    test('the control: a file named under "./" is read by its path', () async {
      final archive = p.join(scratch, 'x.tar.gz');
      File(
        archive,
      ).writeAsBytesSync(gzipCompress(rawMembers(['./', './build_info.json'])));

      check(await tarGzRootFile(archive, 'build_info.json')).isNotNull();
    });
  });

  test('hashes a file as sha256 does', () async {
    final file = File(p.join(scratch, 'abc'))..writeAsStringSync('abc');

    check(await dartFileSha256(file.path)).equals(
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
  });
}

/// The message of the [TarException] [it] checks.
Subject<String> _message(Subject<TarException> it) =>
    it.has((e) => e.message, 'message');

/// A gzip file of one dynamic deflate block, whose code-length code gives
/// each code-length symbol the length [codeLengths] gives it, and whose
/// literal/length and distance codes give each symbol the length
/// [literals] and [distances] give it, coding [symbols]: each a
/// literal/length symbol, with the distance symbol of a length symbol,
/// whose extra bits are all 0. Its trailer records [output].
///
/// Each run of zero lengths is coded with symbol 18, so must be 11 long at
/// least.
Uint8List _gzipOfDynamicBlock({
  required Map<int, int> codeLengths,
  required Map<int, int> literals,
  required List<int> distances,
  required List<(int, int?)> symbols,
  required String output,
}) {
  final bytes = <int>[];
  var bits = 0;
  var count = 0;
  void put(int value, int length) {
    bits |= value << count;
    count += length;
    while (count >= 8) {
      bytes.add(bits & 0xff);
      bits >>= 8;
      count -= 8;
    }
  }

  /// The canonical codes of [lengths], by symbol, as RFC 1951 assigns them.
  Map<int, int> codes(Map<int, int> lengths) {
    final next = List.filled(16, 0);
    for (var length = 1, code = 0; length < 16; length++) {
      next[length] = code;
      code = (code + lengths.values.where((l) => l == length).length) << 1;
    }
    return {
      for (final symbol in lengths.keys.toList()..sort())
        if (lengths[symbol]! > 0) symbol: next[lengths[symbol]!]++,
    };
  }

  void putCode(Map<int, int> lengths, Map<int, int> code, int symbol) {
    for (var bit = lengths[symbol]! - 1; bit >= 0; bit--) {
      put(code[symbol]! >> bit & 1, 1);
    }
  }

  const order = [
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
  final literalCount = (literals.keys.toList()..sort()).last + 1;
  final last = order.lastIndexWhere(codeLengths.containsKey) + 1;
  put(1, 1); // the last block
  put(2, 2); // dynamic codes
  put(literalCount - 257, 5);
  put(distances.length - 1, 5);
  put(last - 4, 4);
  for (final symbol in order.take(last)) {
    put(codeLengths[symbol] ?? 0, 3);
  }
  final codeLengthCode = codes(codeLengths);
  final lengths = [
    for (var symbol = 0; symbol < literalCount; symbol++) literals[symbol] ?? 0,
    ...distances,
  ];
  for (var index = 0; index < lengths.length;) {
    if (lengths[index] != 0) {
      putCode(codeLengths, codeLengthCode, lengths[index++]);
      continue;
    }
    var run = 0;
    while (index + run < lengths.length && lengths[index + run] == 0) {
      run++;
    }
    index += run;
    while (run > 0) {
      final take = run > 138 ? 138 : run;
      if (take < 11) throw ArgumentError('a run of $take zero lengths');
      putCode(codeLengths, codeLengthCode, 18);
      put(take - 11, 7);
      run -= take;
    }
  }
  final literalCode = codes(literals);
  final distanceLengths = distances.asMap();
  final distanceCode = codes(distanceLengths);
  for (final (symbol, distance) in symbols) {
    putCode(literals, literalCode, symbol);
    if (distance != null) putCode(distanceLengths, distanceCode, distance);
  }
  if (count > 0) put(0, 8 - count);
  final decoded = utf8.encode(output);
  int le(int value, int index) => value >> (8 * index) & 0xff;
  final crc = crc32(decoded);
  return Uint8List.fromList([
    ...[0x1f, 0x8b, 8, 0, 0, 0, 0, 0, 0, 0xff],
    ...bytes,
    for (var index = 0; index < 4; index++) le(crc, index),
    for (var index = 0; index < 4; index++) le(decoded.length, index),
  ]);
}

/// A gzip file of one fixed-code deflate block, the last, holding [codes],
/// each a Huffman code and its length in bits, written from its most
/// significant bit, as RFC 1951 writes a Huffman code. Its trailer
/// records [output].
Uint8List _gzipOfFixedBlock(List<(int, int)> codes, {required String output}) {
  final bytes = <int>[];
  var bits = 0;
  var count = 0;
  void put(int bit) {
    bits |= bit << count++;
    if (count == 8) {
      bytes.add(bits);
      bits = 0;
      count = 0;
    }
  }

  put(1); // the last block
  put(1); // fixed codes, 01, from its least significant bit
  put(0);
  for (final (code, length) in codes) {
    for (var bit = length - 1; bit >= 0; bit--) {
      put(code >> bit & 1);
    }
  }
  while (count > 0) {
    put(0);
  }
  final decoded = utf8.encode(output);
  int le(int value, int index) => value >> (8 * index) & 0xff;
  final crc = crc32(decoded);
  return Uint8List.fromList([
    ...[0x1f, 0x8b, 8, 0, 0, 0, 0, 0, 0, 0xff],
    ...bytes,
    for (var index = 0; index < 4; index++) le(crc, index),
    for (var index = 0; index < 4; index++) le(decoded.length, index),
  ]);
}
