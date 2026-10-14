/// Moves a finished build's directory to `output/`.
library;

import 'dart:io';

/// Renames the directory [from] to [to] and returns the renamed directory.
///
/// A typedef so tests can fail the rename without a file system.
typedef DirectoryRename = Directory Function(String from, String to);

/// Waits for [duration].
///
/// A typedef so tests can retry without waiting.
typedef Delay = Future<void> Function(Duration duration);

/// The waits between attempts at the rename on Windows, 15.75 s in all.
const outputRenameDelays = [
  Duration(milliseconds: 250),
  Duration(milliseconds: 500),
  Duration(seconds: 1),
  Duration(seconds: 2),
  Duration(seconds: 4),
  Duration(seconds: 8),
];

/// `ERROR_ACCESS_DENIED`.
const _accessDenied = 5;

Directory _rename(String from, String to) => Directory(from).renameSync(to);

/// Renames the directory [from] to [to] and returns the renamed directory.
///
/// On Windows, a rename refused with `ERROR_ACCESS_DENIED` is tried again
/// after each of [outputRenameDelays], and the last refusal is thrown as a
/// [PathAccessException] naming the attempts; any other failure, and any
/// failure off Windows, where errno 5 is `EIO`, is thrown as it is, at
/// once. An x64 Dart on Windows on arm64 needs it: the x64 emulation layer
/// holds a freshly built x64 DLL open for up to a few seconds after the
/// first process that loaded it, `tool/check_release.dart`, has exited, and
/// a directory holding an open file cannot be renamed meanwhile. Trying
/// again is safe because nothing writes to [from] between the attempts:
/// the rename either moves the directory every check has passed as it is,
/// or leaves it where it was.
Future<Directory> renameOutput(
  String from,
  String to, {
  required bool isWindows,
  DirectoryRename rename = _rename,
  Delay delay = Future<void>.delayed,
}) async {
  for (var attempt = 0; ; attempt++) {
    try {
      return rename(from, to);
    } on FileSystemException catch (error) {
      if (!isWindows || error.osError?.errorCode != _accessDenied) rethrow;
      if (attempt == outputRenameDelays.length) {
        final waited = outputRenameDelays.fold(Duration.zero, (a, b) => a + b);
        throw PathAccessException(
          error.path ?? from,
          error.osError!,
          'Rename to $to failed ${attempt + 1} times over '
          '${waited.inMilliseconds / 1000} s',
        );
      }
      await delay(outputRenameDelays[attempt]);
    }
  }
}
