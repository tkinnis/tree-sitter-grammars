/// Parses one source with one grammar library, then reparses it after an
/// edit, as the editor does after a keystroke.
///
/// Usage:
///
/// ```sh
/// dart run tool/parse_input.dart <runtime> <grammar library> <symbol> <source>
/// ```
///
/// `<runtime>` is a `libtree-sitter.dylib`, `<grammar library>` a grammar's
/// library and `<symbol>` the `tree_sitter_<symbol>` function it exports.
/// The source is parsed, a newline is appended through `ts_tree_edit`, and
/// the longer text is parsed again with the edited tree, so the grammar's
/// scanner serializes its state and restores it from what it serialized.
/// It prints what it parsed and exits 0.
///
/// `tool/check_release.dart` runs it in a process of its own for every
/// crash test, since a grammar whose scanner aborts or overruns its state
/// ends the whole process that loaded it.
library;

import 'dart:io';

import 'src/tree_sitter_ffi.dart';

void main(List<String> args) {
  if (args.length != 4) {
    stderr.writeln(
      'usage: dart run tool/parse_input.dart <runtime> <grammar library> '
      '<symbol> <source>',
    );
    exit(64);
  }
  final [runtimePath, libraryPath, symbol, sourcePath] = args;
  try {
    final runtime = TreeSitterRuntime.open(runtimePath);
    final language = openLanguage(libraryPath, symbol);
    final text = File(sourcePath).readAsStringSync();
    runtime.parseAndReparse(language, text, '\n');
    print('parsed $sourcePath and reparsed it after an edit');
  } on Object catch (error) {
    stderr.writeln('✗ $error');
    exit(1);
  }
}
