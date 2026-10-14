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

    test('when its gzip stream is cut short', () async {
      // dart:io's gzip decodes what it is given and does not report the
      // missing end, so the tar stream it holds is cut short, here inside
      // a member. Reddened by _readTarGz's rethrowing readTar's
      // TarException as it is, which does not name the archive.
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
        (it) => _message(it).startsWith('$archive: the tar stream ends '),
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
    // writing a member: here a file under a path that is a file.
    final archive = p.join(scratch, 'x.tar.gz');
    File(
      archive,
    ).writeAsBytesSync(gzipCompress(_rawStream(['top/a', 'top/a/b'])));
    final destination = p.join(scratch, 'out');

    await check(
      unpackTarGz(archive, destination, stripComponents: 1),
    ).throws<TarException>(
      (it) =>
          _message(it).startsWith('$archive: top/a/b could not be unpacked: '),
    );
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
