/// Parsing in a process of its own, so a grammar whose scanner aborts or
/// crashes ends only that process: what a run of one says, and the lines
/// a process parsing many inputs writes and its parent reads.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'tree_sitter_ffi.dart' show Capture, Parsed;

/// How long a parse in a process of its own may run before the process is
/// killed as hung.
const parseProcessTimeout = Duration(seconds: 60);

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

/// The line a process parsing many inputs writes once it is ready to
/// parse them, before the line of the first.
const parsesReadyLine = 'ready';

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
          file: [for (final capture in list! as List) _decodeCapture(capture)],
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

/// Writes [parsesReadyLine] to [out], then what [parse] makes of each of
/// [texts] from the one at index [first], one line each as [encodeParsed]
/// writes it.
///
/// Each line is flushed before the next parse starts, so when a parse
/// ends the process, every line before it has reached the parent and the
/// first text with no line is the one that ended it.
Future<void> writeParses(
  List<String> texts,
  int first,
  Parsed Function(String text) parse,
  IOSink out,
) async {
  out.writeln(parsesReadyLine);
  await out.flush();
  for (final text in texts.skip(first)) {
    out.writeln(encodeParsed(parse(text)));
    await out.flush();
  }
}

/// One input a parse process ended on, by its index, with what is wrong
/// with the run, as [parseProcessProblem] words it.
typedef ParseFailure = ({int index, String problem});

/// What [parseInProcesses] read: the parse of each input, null for one a
/// process ended on or never reached; each input a process ended on; and,
/// when a process ended before it was ready, what is wrong with that run,
/// after which no input is parsed.
typedef ProcessParses = ({
  List<Parsed?> parsed,
  List<ParseFailure> failures,
  String? startProblem,
});

/// Parses [count] inputs through processes [start] starts, each told the
/// index of the first input it is to parse and writing the lines
/// [writeParses] writes.
///
/// A process that ends before writing the parse of every input it was
/// given, or writes no line for [timeout] and is killed, ended on the
/// first input it wrote no parse of. That input is a failure, and a new
/// process parses the inputs after it.
Future<ProcessParses> parseInProcesses(
  int count,
  Future<Process> Function(int first) start, {
  Duration timeout = parseProcessTimeout,
}) async {
  final parsed = List<Parsed?>.filled(count, null);
  final failures = <ParseFailure>[];
  var next = 0;
  while (next < count) {
    final run = await _readParses(await start(next), parsed, next, timeout);
    if (!run.ready) {
      return (
        parsed: parsed,
        failures: failures,
        startProblem: run.problem ?? 'the process wrote no $parsesReadyLine',
      );
    }
    next = run.next;
    if (next < count) {
      failures.add((
        index: next,
        problem: run.problem ?? 'the process exited 0 before parsing it',
      ));
      next++;
    }
  }
  return (parsed: parsed, failures: failures, startProblem: null);
}

/// Reads the lines [process] writes into [parsed] from index [first] and
/// returns whether it was ready, the index after the last parse it wrote,
/// and what is wrong with its run.
///
/// The process is killed once it has written every parse, has ended, has
/// written no line for [timeout], or has written a line that is not what
/// [writeParses] writes, which is thrown as a [FormatException], so none
/// outlives the reading. A process that has already ended keeps the exit
/// code it ended with.
Future<({bool ready, int next, String? problem})> _readParses(
  Process process,
  List<Parsed?> parsed,
  int first,
  Duration timeout,
) async {
  final errors = process.stderr.transform(utf8.decoder).join();
  final lines = StreamIterator(
    process.stdout.transform(utf8.decoder).transform(const LineSplitter()),
  );
  var ready = false;
  var next = first;
  var hung = false;
  try {
    while (next < parsed.length && await lines.moveNext().timeout(timeout)) {
      if (ready) {
        parsed[next++] = decodeParsed(lines.current);
      } else if (lines.current == parsesReadyLine) {
        ready = true;
      } else {
        throw FormatException('not $parsesReadyLine', lines.current);
      }
    }
  } on TimeoutException {
    hung = true;
  } finally {
    process.kill(ProcessSignal.sigkill);
    await lines.cancel();
  }
  final exitCode = await process.exitCode;
  final problem = parseProcessProblem(
    hung ? null : exitCode,
    await errors,
    timeout: timeout,
  );
  return (ready: ready, next: next, problem: problem);
}
