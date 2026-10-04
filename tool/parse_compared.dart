/// Parses the inputs `tool/check_release.dart --against` compares with the
/// other archive's library of one grammar, in a process of its own.
///
/// Usage:
///
/// ```sh
/// dart run tool/parse_compared.dart <request> <first> <results>
/// ```
///
/// `<request>` is a JSON file naming the `runtime`, a `libtree-sitter.dylib`;
/// the grammar's `library` and the `symbol` whose `tree_sitter_<symbol>`
/// function it exports; the directory of its `queries` and the query
/// `files` to compose there; and the `texts` to parse. A query file that
/// is not there, names a language it cannot inherit from or does not
/// compile is left out. Once the language is open and the queries
/// compiled, it writes to the file `<results>` a line naming the query
/// files it compiled, then parses each text from the one at index
/// `<first>` and writes, for each, a line of JSON holding the tree, its
/// nodes and the captures of each of those files, in the file before the
/// next parse starts. It writes nothing to stdout, which the grammar's
/// scanner may write to. A scanner that aborts or crashes on a text ends
/// the process with every line before that text written, so
/// `tool/check_release.dart` names the text it ended on and starts the
/// process again from the text after it.
library;

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'src/parse_process.dart';
import 'src/release_check.dart';
import 'src/tree_sitter_ffi.dart';

const _usage =
    'usage: dart run tool/parse_compared.dart <request> <first> <results>';

void main(List<String> args) {
  final first = args.length == 3 ? int.tryParse(args[1]) : null;
  if (first == null || first < 0) {
    stderr.writeln(_usage);
    exitCode = 64;
    return;
  }
  try {
    final request = jsonDecode(File(args[0]).readAsStringSync());
    if (request case {
      'runtime': final String runtimePath,
      'library': final String library,
      'symbol': final String symbol,
      'queries': final String directory,
      'files': final List<Object?> files,
      'texts': final List<Object?> texts,
    }) {
      final runtime = TreeSitterRuntime.open(runtimePath);
      final language = openLanguage(library, symbol);
      final queries = _compile(runtime, language, directory, files.cast());
      writeParses(
        args[2],
        queries.keys.toList(),
        texts.cast(),
        first,
        (text) => runtime.parse(language, text, queries),
      );
    } else {
      throw FormatException('${args[0]} is not a request');
    }
  } on Object catch (error) {
    stderr.writeln('✗ $error');
    exitCode = 1;
  }
}

/// Every one of [files] in [directory] that is there, composes and
/// compiles with [language], by name.
Map<String, Query> _compile(
  TreeSitterRuntime runtime,
  Pointer<Void> language,
  String directory,
  List<String> files,
) => {
  for (final file in files)
    if (_compileOne(runtime, language, directory, file) case final query?)
      file: query,
};

Query? _compileOne(
  TreeSitterRuntime runtime,
  Pointer<Void> language,
  String directory,
  String file,
) {
  try {
    return switch (composeQuery(directory, file)) {
      final source? => runtime.compile(language, source),
      null => null,
    };
  } on QueryInheritanceException {
    return null;
  } on QueryException {
    return null;
  }
}
