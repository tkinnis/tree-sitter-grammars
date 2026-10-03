import 'dart:convert';
import 'dart:io';

import 'package:checks/checks.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../tool/src/parse_process.dart';
import '../tool/src/tree_sitter_ffi.dart' show Parsed;

/// A stand-in for `tool/parse_compared.dart` that writes its parses with
/// [writeParses]: it reads the texts from the JSON file its first argument
/// names and parses each from the index its second argument gives into
/// the results file its third names, making of each a parse that names it
/// and naming `highlights.scm` as its one query file. `abort` writes a
/// line and bytes that are not UTF-8 to stderr and ends the process
/// through libc's `abort()`, as a scanner's failed assertion does, and
/// `hang` never returns. Given a fourth argument, `refuse` refuses to
/// start; `unready` writes a line of its own to the results file before
/// its ready line; `garble` writes the lines itself, with a line of its own
/// in place of the parse of `garble`; `chatter` writes to stdout before its
/// ready line and in each parse; and `linger` never ends once it has
/// written every parse.
String _standIn() =>
    '''
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import '${p.toUri(p.absolute('tool', 'src', 'parse_process.dart'))}';
import '${p.toUri(p.absolute('tool', 'src', 'tree_sitter_ffi.dart'))}' show Parsed;

final _abort = DynamicLibrary.process()
    .lookupFunction<Void Function(), void Function()>('abort');

void main(List<String> args) {
  final [request, first, results, ...rest] = args;
  final mode = rest.firstOrNull;
  if (mode == 'refuse') {
    stderr.writeln('✗ no library');
    exitCode = 2;
    return;
  }
  final texts = (jsonDecode(File(request).readAsStringSync()) as List)
      .cast<String>();
  if (mode == 'garble') {
    final out = File(results).openSync(mode: FileMode.writeOnlyAppend);
    out.writeStringSync('\${encodeReady(['highlights.scm'])}\\n');
    for (final text in texts.skip(int.parse(first))) {
      out.writeStringSync(
        text == 'garble' ? 'scanner debug\\n' : '\${encodeParsed(_parse(text))}\\n',
      );
    }
    return;
  }
  if (mode == 'unready') File(results).writeAsStringSync('scanner debug\\n');
  if (mode == 'chatter') stdout.writeln('scanner debug');
  writeParses(results, ['highlights.scm'], texts, int.parse(first), (text) {
    if (mode == 'chatter') stdout.write('scanner debug, no newline');
    return _parse(text);
  });
  if (mode == 'linger') sleep(const Duration(hours: 1));
}

Parsed _parse(String text) {
  if (text == 'abort') {
    stderr
      ..writeln('Assertion failed: (stand-in)')
      ..add([0xff, 0xfe, 0x0a]);
    _abort();
  }
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

  /// The directory the stand-in's results files are written in.
  String resultsDirectory() => p.join(scratch.path, 'results');

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
    return parseInProcesses(
      texts.length,
      (first, results) {
        starts?.add(first);
        return Process.start(Platform.resolvedExecutable, [
          '--packages=${p.absolute('.dart_tool', 'package_config.json')}',
          standIn,
          request.path,
          '$first',
          results,
          ?mode,
        ]);
      },
      scratch: resultsDirectory(),
      timeout: timeout,
    );
  }

  group('parseInProcesses', () {
    test('reads every parse one process writes', () async {
      final starts = <int>[];

      final result = await parse(['a', 'b', 'c'], starts: starts);

      check(starts).deepEquals([0]);
      check(result.failures).isEmpty();
      check(result.startProblem).isNull();
      check(result.queries).isNotNull().deepEquals(['highlights.scm']);
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
      check(result.queries).isNotNull().deepEquals(['highlights.scm']);
      check(Directory(resultsDirectory()).listSync()).isEmpty();
      check(
        result.parsed.map((parsed) => parsed?.tree).toList(),
      ).deepEquals(['(a)', null, '(b)', '(c)', null, '(d)']);
      check(result.failures.map((failure) => failure.index)).deepEquals([1, 4]);
      for (final failure in result.failures) {
        check(failure.problem).equals(
          'the parse ended the process with SIGABRT: Assertion failed: '
          '(stand-in)',
        );
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

    test('reads every parse past what the scanner writes to stdout', () async {
      final result = await parse(['a', 'b'], mode: 'chatter');

      check(result.startProblem).isNull();
      check(result.failures).isEmpty();
      check(
        result.parsed.map((parsed) => parsed?.tree).toList(),
      ).deepEquals(['(a)', '(b)']);
    });

    test('names the input a process writes a line that is not a parse for '
        'and parses every one after it', () async {
      final starts = <int>[];

      final result = await parse(
        ['a', 'garble', 'b'],
        starts: starts,
        mode: 'garble',
      );

      check(starts).deepEquals([0, 2]);
      check(result.startProblem).isNull();
      check(
        result.parsed.map((parsed) => parsed?.tree).toList(),
      ).deepEquals(['(a)', null, '(b)']);
      check(result.failures.single.index).equals(1);
      check(
        result.failures.single.problem,
      ).startsWith('the process wrote a line that is not a parse: ');
    });

    test('a process whose first line is not its ready line parses '
        'nothing', () async {
      final result = await parse(['a'], mode: 'unready');

      check(result.parsed).deepEquals([null]);
      check(result.queries).isNull();
      check(result.startProblem).isNotNull().startsWith(
        'the process wrote a line that is not a ready line: ',
      );
    });

    test('a process that does not start parses nothing', () async {
      final result = await parseInProcesses(
        1,
        (first, results) =>
            Process.start(p.join(scratch.path, 'no such parser'), [results]),
        scratch: resultsDirectory(),
      );

      check(result.parsed).deepEquals([null]);
      check(
        result.startProblem,
      ).isNotNull().startsWith('no process started: ProcessException');
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

    test('decodeReady reads back the query files encodeReady names', () {
      final line = encodeReady(['highlights.scm', 'tags.scm']);

      check(decodeReady(line)).deepEquals(['highlights.scm', 'tags.scm']);
      check(decodeReady(encodeReady([]))).isEmpty();
    });

    test('decodeReady refuses a line that is not a ready line', () {
      check(() => decodeReady('ready')).throws<FormatException>();
      check(() => decodeReady('{"ready": "h.scm"}')).throws<FormatException>();
      check(() => decodeReady('{"ready": [1]}')).throws<FormatException>();
    });

    test('decodeParsed refuses a line that is not a parse', () {
      check(
        () =>
            decodeParsed('{"tree": "", "nodes": "", "captures": {"h.scm": 5}}'),
      ).throws<FormatException>();
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
