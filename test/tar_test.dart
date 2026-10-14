import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../tool/src/tar.dart';

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
      ..add(_rawHeader('pax', 'x', pax.length))
      ..add(pax)
      ..add(Uint8List(512 - pax.length))
      ..add(_rawHeader('short', '0', 0))
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
      File(archive).writeAsBytesSync(gzipCompress(_rawStream([member])));

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
        final header = _rawHeader(
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
      final header = _rawHeader(
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
          ..add(_rawHeader('pax', 'x', pax.length))
          ..add(pax)
          ..add(Uint8List(512 - pax.length))
          ..add(_rawHeader('short', '0', 0))
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
    // the refused ones, are written and unpacked.
    final allowedNames = [
      'CONSOLE', 'con_x.c', 'nul-x', 'COM10', 'COM', 'LPT', 'auxiliary.h', //
      'x.NUL', 'x.con.c', 'a.b.c', '.hidden', 'COMx', 'lpt${superscriptOne}x',
      'caf\u00e9.c', 'a b.c', 'a+b=c,d;e[f]g{h}~', 'x\x7f',
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
        ).writeAsBytesSync(gzipCompress(_rawStream(['top/a.c', 'top/$name'])));
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
    ).writeAsBytesSync(gzipCompress(_rawStream(['top/a.c', 'top/../../evil'])));
    final destination = p.join(scratch, 'out');

    await check(
      unpackTarGz(archive, destination, stripComponents: 1),
    ).throws<TarException>();
    check(File(p.join(destination, 'a.c')).existsSync()).isFalse();
  });

  test('a member the file system will not write is refused', () async {
    // Reddened by dropping unpackTarGz's catch of the FileSystemException
    // writing a member: here a file under a destination that is a file,
    // which no check of the archive's own members can see.
    final archive = p.join(scratch, 'x.tar.gz');
    File(archive).writeAsBytesSync(gzipCompress(_rawStream(['top/a'])));
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
    // Each case's members, as _rawMembers reads them, and the start of the
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
        File(archive).writeAsBytesSync(gzipCompress(_rawMembers(members)));
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
          _rawMembers([
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

/// A ustar header of [type] for a member [name] of [size] bytes, with
/// [edit] made to it before its checksum is computed.
Uint8List _rawHeader(
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
Uint8List _rawStream(List<String> paths) => Uint8List.fromList([
  for (final path in paths) ..._rawHeader(path, '0', 0),
  ...Uint8List(1024),
]);

/// A tar stream of [members], written header by header and ended as an
/// archive is: a directory for each that ends in `/`, and otherwise an
/// empty file.
Uint8List _rawMembers(List<String> members) => Uint8List.fromList([
  for (final member in members)
    ..._rawHeader(member, member.endsWith('/') ? '5' : '0', 0),
  ...Uint8List(1024),
]);
