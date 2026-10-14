import 'dart:io';

import 'package:checks/checks.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../tool/src/output_rename.dart';

/// A rename that throws each of [failures] in turn, then renames.
final class _FakeRename {
  _FakeRename(this.failures);

  final List<FileSystemException> failures;
  final calls = <(String, String)>[];

  Directory call(String from, String to) {
    calls.add((from, to));
    if (calls.length <= failures.length) throw failures[calls.length - 1];
    return Directory(to);
  }
}

/// A delay that records what it is asked to wait and does not wait.
final class _FakeDelay {
  final waits = <Duration>[];

  Future<void> call(Duration duration) async => waits.add(duration);
}

/// The error `renameSync` throws for an emulated x64 DLL still held open:
/// ERROR_ACCESS_DENIED.
PathAccessException _accessDenied() => const PathAccessException(
  r'build\out',
  OSError('Access is denied', 5),
  'Rename failed',
);

Duration _ms(int milliseconds) => Duration(milliseconds: milliseconds);

void main() {
  group('renameOutput', () {
    test('renames a directory on the host', () async {
      final temp = Directory.systemTemp.createTempSync('output_rename_');
      addTearDown(() => temp.deleteSync(recursive: true));
      final from = Directory(p.join(temp.path, 'out'))..createSync();
      File(p.join(from.path, 'a')).writeAsStringSync('a');
      final to = p.join(temp.path, 'output');

      final renamed = await renameOutput(
        from.path,
        to,
        isWindows: Platform.isWindows,
      );

      check(renamed.path).equals(to);
      check(File(p.join(to, 'a')).readAsStringSync()).equals('a');
      check(from.existsSync()).isFalse();
    });

    test('on Windows, retries a rename refused with errno 5, after a '
        'growing wait, until it succeeds', () async {
      // An x64 build on Windows on arm64 has the emulator still holding a
      // DLL the checks loaded for up to a few seconds after they exit, and
      // the rename is refused as access denied meanwhile. Mutation: rename
      // once, with no retry; this reddens.
      final rename = _FakeRename([
        _accessDenied(),
        _accessDenied(),
        _accessDenied(),
      ]);
      final delay = _FakeDelay();

      final renamed = await renameOutput(
        'out',
        'output',
        isWindows: true,
        rename: rename.call,
        delay: delay.call,
      );

      check(renamed.path).equals('output');
      check(
        rename.calls,
      ).deepEquals([for (var i = 0; i < 4; i++) ('out', 'output')]);
      check(delay.waits).deepEquals([_ms(250), _ms(500), _ms(1000)]);
    });

    test('on Windows, gives up after 7 attempts over 15.75 s and throws '
        'the last error, naming them', () async {
      // Mutation: retry while the rename is refused, with no bound; this
      // reddens (the 21st attempt renames and nothing is thrown). Mutation:
      // rethrow the last error as it is, without the attempts; this
      // reddens.
      final failures = [for (var i = 0; i < 20; i++) _accessDenied()];
      final rename = _FakeRename(failures);
      final delay = _FakeDelay();

      await check(
        renameOutput(
          'out',
          'output',
          isWindows: true,
          rename: rename.call,
          delay: delay.call,
        ),
      ).throws<PathAccessException>(
        (it) => it
          ..has((e) => e.path, 'path').equals(r'build\out')
          ..has((e) => e.osError?.errorCode, 'errno').equals(5)
          ..has(
            (e) => e.message,
            'message',
          ).equals('Rename to output failed 7 times over 15.75 s'),
      );
      check(rename.calls).length.equals(7);
      check(delay.waits).deepEquals([
        _ms(250),
        _ms(500),
        _ms(1000),
        _ms(2000),
        _ms(4000),
        _ms(8000),
      ]);
    });

    test('on Windows, names the directory it renames where the last error '
        'names no path', () async {
      // Mutation: name '' in place of [from] where the error has no path;
      // this reddens.
      const failure = FileSystemException(
        'Rename failed',
        null,
        OSError('Access is denied', 5),
      );
      final rename = _FakeRename([for (var i = 0; i < 7; i++) failure]);

      await check(
        renameOutput(
          'out',
          'output',
          isWindows: true,
          rename: rename.call,
          delay: _FakeDelay().call,
        ),
      ).throws<PathAccessException>(
        (it) => it..has((e) => e.path, 'path').equals('out'),
      );
    });

    test('on Windows, does not retry a rename refused with another errno or '
        'none', () async {
      // ERROR_SHARING_VIOLATION, ERROR_ALREADY_EXISTS and an error with no
      // OS error say nothing of a DLL the emulator holds. Mutation: retry
      // any FileSystemException; this reddens.
      for (final failure in [
        const FileSystemException('Rename failed', 'out', OSError('x', 32)),
        const FileSystemException('Rename failed', 'out', OSError('x', 183)),
        const FileSystemException('Rename failed', 'out'),
      ]) {
        final rename = _FakeRename([failure]);
        final delay = _FakeDelay();

        await check(
          renameOutput(
            'out',
            'output',
            isWindows: true,
            rename: rename.call,
            delay: delay.call,
          ),
        ).throws<FileSystemException>((it) => it.identicalTo(failure));
        check(rename.calls).length.equals(1);
        check(delay.waits).isEmpty();
      }
    });

    test('off Windows, does not retry errno 5', () async {
      // errno 5 is EIO on macOS and Linux, a failure no wait mends.
      // Mutation: retry errno 5 on every host; this reddens.
      final failure = _accessDenied();
      final rename = _FakeRename([failure]);
      final delay = _FakeDelay();

      await check(
        renameOutput(
          'out',
          'output',
          isWindows: false,
          rename: rename.call,
          delay: delay.call,
        ),
      ).throws<PathAccessException>((it) => it.identicalTo(failure));
      check(rename.calls).length.equals(1);
      check(delay.waits).isEmpty();
    });
  });
}
