/// Checks that `tool/query_provenance.json` has exactly one well-formed entry
/// for every `.scm` file under `queries/`.
///
/// Usage: `dart run tool/check_query_provenance.dart`
///
/// Exits 1 and lists each problem when the check fails.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import 'src/query_provenance.dart';

void main() {
  final root = p.dirname(p.dirname(p.fromUri(Platform.script)));
  final queriesDir = Directory(p.join(root, 'queries'));
  final queryFiles = [
    for (final entity in queriesDir.listSync(recursive: true))
      if (entity is File && entity.path.endsWith('.scm'))
        p.posix.joinAll(p.split(p.relative(entity.path, from: root))),
  ]..sort();
  final json =
      File(p.join(root, 'tool', 'query_provenance.json')).readAsStringSync();
  final (:entries, :problems) = readQueryProvenance(json, queryFiles);
  for (final problem in problems) {
    stderr.writeln('query_provenance.json: $problem');
  }
  final byOrigin = <QueryOrigin, int>{};
  for (final entry in entries.values) {
    byOrigin[entry.origin] = (byOrigin[entry.origin] ?? 0) + 1;
  }
  print('${queryFiles.length} query files, ${entries.length} entries, '
      '${problems.length} problems');
  print([
    for (final origin in QueryOrigin.values)
      '${origin.name} ${byOrigin[origin] ?? 0}',
  ].join(', '));
  if (problems.isNotEmpty) exit(1);
}
