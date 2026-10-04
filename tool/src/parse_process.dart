/// Parsing in a process of its own, so a grammar whose scanner aborts or
/// crashes ends only that process: what a run of one says, and the lines a
/// process parsing many inputs writes to its results file and its parent
/// reads.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'tree_sitter_ffi.dart' show Capture, Parsed;

/// How long a parse in a process of its own may run before the process is
/// killed as hung.
const parseProcessTimeout = Duration(seconds: 60);

/// How often a parent reads a process's results file for the lines written
/// to it since the last read.
const _pollInterval = Duration(milliseconds: 10);

/// The names of the signals a parse process can end by, by number.
const _signalNames = {
  4: 'SIGILL',
  5: 'SIGTRAP',
  6: 'SIGABRT',
  8: 'SIGFPE',
  9: 'SIGKILL',
  10: 'SIGBUS',
  11: 'SIGSEGV',
};

/// What is wrong with one run of a parse process, or null when it exited 0.
///
/// [exitCode] is the process's exit code as `dart:io` reports it, negative
/// for a process ended by a signal, or null when it ran past [timeout] and
/// was killed. [stderr] is what it wrote there, of which the first
/// non-empty line is quoted.
String? parseProcessProblem(
  int? exitCode,
  String stderr, {
  Duration timeout = parseProcessTimeout,
}) {
  final said = const LineSplitter()
      .convert(stderr)
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .firstOrNull;
  final saying = said == null ? '' : ': $said';
  return switch (exitCode) {
    0 => null,
    null => 'the parse ran past ${timeout.inSeconds} seconds and was killed',
    < 0 =>
      'the parse ended the process with '
          '${_signalNames[-exitCode] ?? 'signal ${-exitCode}'}$saying',
    _ => 'the parse exited $exitCode$saying',
  };
}

/// All of [output], a process's stdout or stderr, as text, each byte that
/// is not UTF-8 read as U+FFFD, since a scanner may write any bytes there.
Future<String> readOutput(Stream<List<int>> output) =>
    output.transform(const Utf8Decoder(allowMalformed: true)).join();

/// The line a process parsing many inputs writes first, once it is ready
/// to parse them, naming the query files whose captures each parse holds.
String encodeReady(List<String> queries) => jsonEncode({'ready': queries});

/// The query files the line [encodeReady] wrote as [line] names.
///
/// Throws a [FormatException] when [line] is not such a line.
List<String> decodeReady(String line) {
  if (jsonDecode(line) case {'ready': final List<Object?> queries}) {
    return [
      for (final query in queries)
        query is String
            ? query
            : throw FormatException('not a query file: $query', line),
    ];
  }
  throw FormatException('not a ready line', line);
}

/// [parsed] as one line of JSON.
String encodeParsed(Parsed parsed) => jsonEncode({
  'tree': parsed.tree,
  'nodes': parsed.nodes,
  'captures': {
    for (final MapEntry(key: file, value: captures) in parsed.captures.entries)
      file: [
        for (final (:name, :start, :end, :properties) in captures)
          [name, start, end, properties],
      ],
  },
});

/// The parse [encodeParsed] wrote as [line].
///
/// Throws a [FormatException] when [line] is not such a parse.
Parsed decodeParsed(String line) {
  if (jsonDecode(line) case {
    'tree': final String tree,
    'nodes': final String nodes,
    'captures': final Map<String, Object?> captures,
  }) {
    return (
      tree: tree,
      nodes: nodes,
      captures: {
        for (final MapEntry(key: file, value: list) in captures.entries)
          file: switch (list) {
            final List<Object?> list => [
              for (final capture in list) _decodeCapture(capture),
            ],
            _ => throw FormatException('not a list of captures: $list', line),
          },
      },
    );
  }
  throw FormatException('not a parse', line);
}

Capture _decodeCapture(Object? capture) => switch (capture) {
  [
    final String name,
    final int start,
    final int end,
    final String properties,
  ] =>
    (name: name, start: start, end: end, properties: properties),
  _ => throw FormatException('not a capture: $capture'),
};

/// Writes to the file at [results] the line [encodeReady] makes of
/// [queries], then what [parse] makes of each of [texts] from the one at
/// index [first], one line each as [encodeParsed] writes it.
///
/// A [RandomAccessFile] holds no buffer of its own, so each line is in the
/// file before the next parse starts: when a parse ends the process, every
/// line before it is there, and the first text with no line is the one
/// that ended it. Nothing is written to stdout, which a scanner may write
/// to as it pleases.
void writeParses(
  String results,
  List<String> queries,
  List<String> texts,
  int first,
  Parsed Function(String text) parse,
) {
  final out = File(results).openSync(mode: FileMode.writeOnlyAppend);
  try {
    out.writeStringSync('${encodeReady(queries)}\n');
    for (final text in texts.skip(first)) {
      out.writeStringSync('${encodeParsed(parse(text))}\n');
    }
  } finally {
    out.closeSync();
  }
}

/// One input a parse process ended on, by its index, with what is wrong
/// with the run.
typedef ParseFailure = ({int index, String problem});

/// What [parseInProcesses] read: the query files the first process to get
/// ready named; the parse of each input, null for one a process ended on
/// or never reached; each input a process ended on; and, when a process
/// failed to start or ended before it was ready, what is wrong with that
/// run, after which no input is parsed.
typedef ProcessParses = ({
  List<String>? queries,
  List<Parsed?> parsed,
  List<ParseFailure> failures,
  String? startProblem,
});

/// Parses [count] inputs through processes [start] starts, each told the
/// index of the first input it is to parse and the path of a results file
/// in the directory [scratch] to write the lines [writeParses] writes.
///
/// What a process writes to stdout is read and set aside, and what it
/// writes to stderr is quoted when its run fails. A process that ends
/// before writing the parse of every input it was given, writes no line
/// for [timeout] and is killed, or writes a line that is not a parse,
/// ended on the first input it wrote no parse of. That input is a failure,
/// and a new process parses the inputs after it.
Future<ProcessParses> parseInProcesses(
  int count,
  Future<Process> Function(int first, String results) start, {
  required String scratch,
  Duration timeout = parseProcessTimeout,
}) async {
  final parsed = List<Parsed?>.filled(count, null);
  final failures = <ParseFailure>[];
  List<String>? queries;
  var next = 0;
  while (next < count) {
    final run = await _readParses(start, scratch, parsed, next, timeout);
    if (run.queries == null) {
      return (
        queries: queries,
        parsed: parsed,
        failures: failures,
        startProblem: run.problem ?? 'the process wrote no ready line',
      );
    }
    queries ??= run.queries;
    next = run.next;
    if (next < count) {
      failures.add((
        index: next,
        problem: run.problem ?? 'the process exited 0 before parsing it',
      ));
      next++;
    }
  }
  return (
    queries: queries,
    parsed: parsed,
    failures: failures,
    startProblem: null,
  );
}

/// Starts a process with [start] and reads the lines it writes to its
/// results file in [scratch] into [parsed] from index [first], returning
/// the query files its ready line names, null when it wrote none, the
/// index after the last parse it wrote, and what is wrong with its run.
///
/// The process is killed once it has written every parse, has ended, has
/// written no line for [timeout], or has written a line that is not what
/// [writeParses] writes, so none outlives the reading. A process that has
/// already ended keeps the exit code it ended with.
Future<({List<String>? queries, int next, String? problem})> _readParses(
  Future<Process> Function(int first, String results) start,
  String scratch,
  List<Parsed?> parsed,
  int first,
  Duration timeout,
) async {
  final results = File(p.join(scratch, 'parses-from-$first'));
  final Process process;
  try {
    results
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(const []);
    process = await start(first, results.path);
  } on IOException catch (error) {
    return (queries: null, next: first, problem: 'no process started: $error');
  }
  final errors = readOutput(process.stderr);
  final output = process.stdout.drain<void>();
  final lines = StreamIterator(
    _written(
      results,
      process.exitCode,
    ).transform(utf8.decoder).transform(const LineSplitter()),
  );
  List<String>? queries;
  var next = first;
  var hung = false;
  String? malformed;
  try {
    while (next < parsed.length && await lines.moveNext().timeout(timeout)) {
      if (queries == null) {
        queries = decodeReady(lines.current);
      } else {
        parsed[next] = decodeParsed(lines.current);
        next++;
      }
    }
  } on TimeoutException {
    hung = true;
  } on FormatException catch (error) {
    malformed =
        'the process wrote a line that is not '
        '${queries == null ? 'a ready line' : 'a parse'}: ${error.message}';
  } finally {
    process.kill(ProcessSignal.sigkill);
    await lines.cancel();
    results.deleteSync();
  }
  final exitCode = await process.exitCode;
  await output;
  final problem =
      malformed ??
      parseProcessProblem(
        hung ? null : exitCode,
        await errors,
        timeout: timeout,
      );
  return (queries: queries, next: next, problem: problem);
}

/// The bytes written to [file], each read within [_pollInterval] of its
/// writing, ending once [exitCode] has completed and every byte written
/// before then has been read.
Stream<List<int>> _written(File file, Future<int> exitCode) async* {
  var ended = false;
  unawaited(exitCode.then((_) => ended = true));
  final reader = await file.open();
  try {
    while (true) {
      final endedBeforeRead = ended;
      final bytes = await reader.read(1 << 16);
      if (bytes.isNotEmpty) {
        yield bytes;
      } else if (endedBeforeRead) {
        return;
      } else {
        await Future<void>.delayed(_pollInterval);
      }
    }
  } finally {
    await reader.close();
  }
}
