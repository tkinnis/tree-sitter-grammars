import 'dart:convert';
import 'dart:io';

import 'package:checks/checks.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../tool/src/parse_process.dart';
import '../tool/src/release_check.dart' show composeQuery, queryFiles;
import '../tool/src/tree_sitter_ffi.dart';

/// The built `output/` whose runtime and JSON grammar these tests run.
final _output = p.absolute('output');
final _runtime = p.join(_output, 'libtree-sitter.dylib');
final _grammar = p.join(_output, 'dylibs', 'json');
final _library = p.join(_grammar, 'libjson.dylib');

void main() {
  final built = File(_runtime).existsSync() && File(_library).existsSync();

  group(
    'tool/parse_compared.dart',
    skip: built ? false : 'needs a built output/ holding the json grammar',
    () {
      late Directory scratch;

      setUp(
        () => scratch = Directory.systemTemp.createTempSync('parse_compared'),
      );
      tearDown(() => scratch.deleteSync(recursive: true));

      test('names the query files it compiles, then writes the parse this '
          'process makes of each text from the index it is given', () async {
        final queries = Directory(p.join(scratch.path, 'json'))..createSync();
        final shipped = queryFiles(_grammar);
        for (final file in shipped) {
          File(p.join(_grammar, file)).copySync(p.join(queries.path, file));
        }
        File(
          p.join(queries.path, 'broken.scm'),
        ).writeAsStringSync('(no_such_node) @x\n');
        const texts = ['{"a": [1, true]}', '[1, null]', '{"b": "text"}'];
        final request = File(p.join(scratch.path, 'request.json'))
          ..writeAsStringSync(
            jsonEncode({
              'runtime': _runtime,
              'library': _library,
              'symbol': 'json',
              'queries': queries.path,
              'files': [...shipped, 'broken.scm', 'absent.scm'],
              'texts': texts,
            }),
          );
        final results = p.join(scratch.path, 'results');

        final run = await Process.run(Platform.resolvedExecutable, [
          p.join('tool', 'parse_compared.dart'),
          request.path,
          '1',
          results,
        ]);

        check(run.exitCode).equals(0);
        check(run.stdout as String).isEmpty();
        final runtime = TreeSitterRuntime.open(_runtime);
        final language = openLanguage(_library, 'json');
        final compiled = {
          for (final file in shipped)
            file: runtime.compile(language, composeQuery(_grammar, file)!),
        };
        final [ready, ...parses] = File(results).readAsLinesSync();
        check(decodeReady(ready)).deepEquals(shipped);
        check(parses).length.equals(texts.length - 1);
        for (final (index, line) in parses.indexed) {
          final expected = runtime.parse(language, texts[index + 1], compiled);
          final parsed = decodeParsed(line);
          check(parsed.tree).equals(expected.tree);
          check(parsed.nodes).equals(expected.nodes);
          check(parsed.captures.keys).deepEquals(shipped);
          check(expected.captures['highlights.scm']!).isNotEmpty();
          for (final MapEntry(:key, :value) in expected.captures.entries) {
            check(parsed.captures[key]!).deepEquals(value);
          }
        }
        for (final query in compiled.values) {
          query.delete();
        }
      });

      test(
        'ends before writing a line when the library does not open',
        () async {
          final request = File(p.join(scratch.path, 'request.json'))
            ..writeAsStringSync(
              jsonEncode({
                'runtime': _runtime,
                'library': p.join(scratch.path, 'libnone.dylib'),
                'symbol': 'none',
                'queries': _grammar,
                'files': <String>[],
                'texts': ['{}'],
              }),
            );
          final results = File(p.join(scratch.path, 'results'))
            ..writeAsBytesSync(const []);

          final run = await Process.run(Platform.resolvedExecutable, [
            p.join('tool', 'parse_compared.dart'),
            request.path,
            '0',
            results.path,
          ]);

          check(run.exitCode).equals(1);
          check(run.stderr as String).contains('libnone.dylib');
          check(results.readAsStringSync()).isEmpty();
        },
      );
    },
  );
}
