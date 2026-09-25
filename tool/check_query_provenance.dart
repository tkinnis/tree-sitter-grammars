/// Checks that `tool/query_provenance.json` has exactly one well-formed entry
/// for every `.scm` file under `queries/`, and that every file derived from
/// nvim-treesitter starts with the header its entry names.
///
/// Usage:
///
/// ```sh
/// dart run tool/check_query_provenance.dart
/// dart run tool/check_query_provenance.dart --write-headers
/// ```
///
/// `--write-headers` first gives every query file the header its entry
/// names, then checks. Exits 1 and lists each problem when the check fails.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import 'src/grammar_pins.dart';
import 'src/query_headers.dart';
import 'src/query_provenance.dart';

void main(List<String> args) {
  final write = switch (args) {
    [] => false,
    ['--write-headers'] => true,
    _ => null,
  };
  if (write == null) {
    stderr.writeln(
      'usage: dart run tool/check_query_provenance.dart [--write-headers]',
    );
    exit(64);
  }
  final root = p.dirname(p.dirname(p.fromUri(Platform.script)));
  final queriesDir = Directory(p.join(root, 'queries'));
  final queryFiles = [
    for (final entity in queriesDir.listSync(recursive: true))
      if (entity is File && entity.path.endsWith('.scm'))
        p.posix.joinAll(p.split(p.relative(entity.path, from: root))),
  ]..sort();
  final json = File(
    p.join(root, 'tool', 'query_provenance.json'),
  ).readAsStringSync();
  final (:entries, :problems) = readQueryProvenance(json, queryFiles);
  final licenseOf = licenseLookup(
    parseGrammars(
      File(p.join(root, 'tool', 'grammars.json')).readAsStringSync(),
    ),
  );
  if (write && problems.isEmpty) {
    for (final file in writeQueryHeaders(root, entries, licenseOf)) {
      print('wrote the header of $file');
    }
  }
  final headerProblems = queryHeaderCheck(root, entries, licenseOf);
  for (final problem in [...problems, ...headerProblems]) {
    stderr.writeln('query_provenance.json: $problem');
  }
  final byOrigin = <QueryOrigin, int>{};
  for (final entry in entries.values) {
    byOrigin[entry.origin] = (byOrigin[entry.origin] ?? 0) + 1;
  }
  final headed = entries.values.where(isNvimDerived).length;
  print(
    '${queryFiles.length} query files, ${entries.length} entries, '
    '${problems.length} problems; $headed nvim-derived headers, '
    '${headerProblems.length} header problems',
  );
  print(
    [
      for (final origin in QueryOrigin.values)
        '${origin.name} ${byOrigin[origin] ?? 0}',
    ].join(', '),
  );
  if (problems.isNotEmpty || headerProblems.isNotEmpty) exit(1);
}
