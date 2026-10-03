import 'dart:convert';
import 'dart:io';

import 'package:checks/checks.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../tool/src/parse_process.dart';
import '../tool/src/tree_sitter_ffi.dart' show Parsed;

/// A stand-in for `tool/parse_compared.dart` that writes its parses with
/// [writeParses]: it reads the texts from the JSON file its first
/// argument names and parses each from the index its second argument
/// gives, making of each a parse that names it. `abort` ends the process through libc's `abort()`, as a
/// scanner's failed assertion does, and `hang` never returns. Given a
/// third argument, `refuse` refuses to start and `linger` never ends once
/// it has written every parse.
String _standIn() =>
    '''
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import '${p.toUri(p.absolute('tool', 'src', 'parse_process.dart'))}';

final _abort = DynamicLibrary.process()
    .lookupFunction<Void Function(), void Function()>('abort');

Future<void> main(List<String> args) async {
  final mode = args.length > 2 ? args[2] : null;
  if (mode == 'refuse') {
    stderr.writeln('✗ no library');
    exitCode = 2;
    return;
  }
  final texts = (jsonDecode(File(args[0]).readAsStringSync()) as List)
      .cast<String>();
  await writeParses(texts, int.parse(args[1]), (text) {
    if (text == 'abort') _abort();
    if (text == 'hang') sleep(const Duration(hours: 1));
    return (
      tree: '(\$text)',
      nodes: 'nodes of \$text',
      captures: {
        'highlights.scm': [
          (name: 'keyword', start: 0, end: text.length, properties: ''),
        ],
      },
    );
  }, stdout);
  if (mode == 'linger') sleep(const Duration(hours: 1));
}
''';

void main() {
  late Directory scratch;
  late String standIn;

  setUpAll(() {
    scratch = Directory.systemTemp.createTempSync('parse_process');
    standIn = p.join(scratch.path, 'stand_in.dart');
    File(standIn).writeAsStringSync(_standIn());
  });

  tearDownAll(() => scratch.deleteSync(recursive: true));

  /// Parses [texts] through the stand-in, recording in [starts] the index
  /// each process it starts is told to begin at.
  Future<ProcessParses> parse(
    List<String> texts, {
    List<int>? starts,
    String? mode,
    Duration timeout = parseProcessTimeout,
  }) {
    final request = File(p.join(scratch.path, 'texts.json'))
      ..writeAsStringSync(jsonEncode(texts));
    return parseInProcesses(texts.length, (first) {
      starts?.add(first);
      return Process.start(Platform.resolvedExecutable, [
        '--packages=${p.absolute('.dart_tool', 'package_config.json')}',
        standIn,
        request.path,
        '$first',
        ?mode,
      ]);
    }, timeout: timeout);
  }

  group('parseInProcesses', () {
    test('reads every parse one process writes', () async {
      final starts = <int>[];

      final result = await parse(['a', 'b', 'c'], starts: starts);

      check(starts).deepEquals([0]);
      check(result.failures).isEmpty();
      check(result.startProblem).isNull();
      check(
        result.parsed.map((parsed) => parsed?.tree).toList(),
      ).deepEquals(['(a)', '(b)', '(c)']);
      check(result.parsed[1]!.nodes).equals('nodes of b');
      check(
        result.parsed[2]!.captures['highlights.scm']!,
      ).deepEquals([(name: 'keyword', start: 0, end: 1, properties: '')]);
    });

    test('names each input a process aborts on and parses every one after '
        'it in a process of its own', () async {
      final starts = <int>[];

      final result = await parse([
        'a',
        'abort',
        'b',
        'c',
        'abort',
        'd',
      ], starts: starts);

      check(starts).deepEquals([0, 2, 5]);
      check(result.startProblem).isNull();
      check(
        result.parsed.map((parsed) => parsed?.tree).toList(),
      ).deepEquals(['(a)', null, '(b)', '(c)', null, '(d)']);
      check(result.failures.map((failure) => failure.index)).deepEquals([1, 4]);
      for (final failure in result.failures) {
        check(
          failure.problem,
        ).startsWith('the parse ended the process with SIGABRT');
      }
    });

    test(
      'names an input a process aborts on as the first or the last',
      () async {
        final result = await parse(['abort', 'a', 'abort']);

        check(
          result.parsed.map((parsed) => parsed?.tree).toList(),
        ).deepEquals([null, '(a)', null]);
        check(
          result.failures.map((failure) => failure.index),
        ).deepEquals([0, 2]);
      },
    );

    test('kills a process that writes nothing for the timeout and names the '
        'input it hung on', () async {
      final starts = <int>[];

      final result = await parse(
        ['a', 'hang', 'b'],
        starts: starts,
        timeout: const Duration(seconds: 10),
      );

      check(starts).deepEquals([0, 2]);
      check(
        result.parsed.map((parsed) => parsed?.tree).toList(),
      ).deepEquals(['(a)', null, '(b)']);
      check(result.failures.single.index).equals(1);
      check(
        result.failures.single.problem,
      ).equals('the parse ran past 10 seconds and was killed');
    });

    test('a process that ends before it is ready parses nothing', () async {
      final starts = <int>[];

      final result = await parse(['a', 'b'], starts: starts, mode: 'refuse');

      check(starts).deepEquals([0]);
      check(result.parsed).deepEquals([null, null]);
      check(result.failures).isEmpty();
      check(result.startProblem).equals('the parse exited 2: ✗ no library');
    });

    test('kills a process that has written every parse', () async {
      final result = await parse([
        'a',
        'b',
      ], mode: 'linger').timeout(const Duration(seconds: 30));

      check(
        result.parsed.map((parsed) => parsed?.tree).toList(),
      ).deepEquals(['(a)', '(b)']);
      check(result.failures).isEmpty();
    });

    test('starts no process for no inputs', () async {
      final starts = <int>[];

      final result = await parse([], starts: starts);

      check(starts).isEmpty();
      check(result.parsed).isEmpty();
      check(result.startProblem).isNull();
    });
  });

  group('encodeParsed', () {
    test('writes one line decodeParsed reads back as it was', () {
      final Parsed parsed = (
        tree: '(document (string))',
        nodes: '0 document 0-9\n1 "\\"" 0-1',
        captures: {
          'highlights.scm': [
            (name: 'string', start: 0, end: 9, properties: ''),
            (
              name: 'injection.content',
              start: 1,
              end: 8,
              properties: '#set! "injection.language" "ünïcode 😀"',
            ),
          ],
          'tags.scm': [],
        },
      );

      final line = encodeParsed(parsed);
      final decoded = decodeParsed(line);

      check(line).not((it) => it.contains('\n'));
      check(decoded.tree).equals(parsed.tree);
      check(decoded.nodes).equals(parsed.nodes);
      check(decoded.captures.keys).deepEquals(parsed.captures.keys);
      for (final MapEntry(:key, :value) in parsed.captures.entries) {
        check(decoded.captures[key]!).deepEquals(value);
      }
    });

    test('decodeParsed refuses a line that is not a parse', () {
      check(() => decodeParsed('{"tree": "(a)"}')).throws<FormatException>();
      check(
        () => decodeParsed(
          '{"tree": "", "nodes": "", "captures": {"h.scm": [["x", 0]]}}',
        ),
      ).throws<FormatException>();
    });
  });

  group('parseProcessProblem', () {
    test('a process that exits 0 passes', () {
      check(parseProcessProblem(0, 'a warning\n')).isNull();
    });

    test('a process a signal ends names the signal and what it said', () {
      check(
        parseProcessProblem(-6, '\nAssertion failed: (length <= 1024)\nmore\n'),
      ).equals(
        'the parse ended the process with SIGABRT: Assertion failed: '
        '(length <= 1024)',
      );
      check(
        parseProcessProblem(-11, ''),
      ).equals('the parse ended the process with SIGSEGV');
      check(
        parseProcessProblem(-30, ''),
      ).equals('the parse ended the process with signal 30');
    });

    test('a process that exits non-zero, or runs too long, fails', () {
      check(
        parseProcessProblem(1, '✗ no lib.dylib'),
      ).equals('the parse exited 1: ✗ no lib.dylib');
      check(
        parseProcessProblem(null, ''),
      ).equals('the parse ran past 60 seconds and was killed');
    });
  });
}
