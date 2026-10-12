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

  test('refuses a member leading out of the destination', () async {
    final archive = p.join(scratch, 'x.tar.gz');
    File(archive).writeAsBytesSync(
      gzipCompress(
        ustar([
          (path: 'top/../../evil', bytes: const [], mode: 0x1a4, epoch: 0),
        ]),
      ),
    );

    await check(
      unpackTarGz(archive, p.join(scratch, 'out'), stripComponents: 1),
    ).throws<TarException>();
  });

  test('hashes a file as sha256 does', () async {
    final file = File(p.join(scratch, 'abc'))..writeAsStringSync('abc');

    check(await dartFileSha256(file.path)).equals(
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
  });
}

/// A ustar header of [type] for a member [name] of [size] bytes.
Uint8List _rawHeader(String name, String type, int size) {
  final header = Uint8List(512);
  header.setAll(0, utf8.encode(name));
  header.setAll(100, ascii.encode('0000644\x00'));
  header.setAll(
    124,
    ascii.encode('${size.toRadixString(8).padLeft(11, '0')}\x00'),
  );
  header[156] = type.codeUnitAt(0);
  header.setAll(257, ascii.encode('ustar\x0000'));
  header.setAll(148, ascii.encode(' ' * 8));
  final sum = header.fold<int>(0, (a, b) => a + b);
  header.setAll(
    148,
    ascii.encode('${sum.toRadixString(8).padLeft(6, '0')}\x00 '),
  );
  return header;
}
