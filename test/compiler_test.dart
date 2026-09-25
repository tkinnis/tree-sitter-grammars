@TestOn('mac-os')
library;

import 'dart:io';

import 'package:checks/checks.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../tool/src/compiler.dart';

/// A stand-in compiler that writes the arguments and environment it
/// received, NUL-separated, to the file after its `-o`.
const _probe = r'''
#include <stdio.h>
#include <string.h>
extern char **environ;
int main(int argc, char **argv) {
  const char *output = 0;
  for (int i = 1; i + 1 < argc; i++)
    if (!strcmp(argv[i], "-o")) output = argv[i + 1];
  if (!output) return 2;
  FILE *file = fopen(output, "w");
  if (!file) return 3;
  for (int i = 0; i < argc; i++) fprintf(file, "%s%c", argv[i], 0);
  fputc('\n', file);
  for (char **variable = environ; *variable; variable++)
    fprintf(file, "%s%c", *variable, 0);
  return fclose(file) ? 4 : 0;
}
''';

void main() {
  late String scratch;
  late String probe;

  setUpAll(() async {
    scratch = Directory.systemTemp.createTempSync('compiler_test').path;
    File(p.join(scratch, 'probe.c')).writeAsStringSync(_probe);
    probe = p.join(scratch, 'probe');
    final result = await Process.run('xcrun', [
      'clang',
      p.join(scratch, 'probe.c'),
      '-o',
      probe,
    ]);
    if (result.exitCode != 0) throw StateError('${result.stderr}');
  });

  tearDownAll(() => Directory(scratch).deleteSync(recursive: true));

  test(
    'runCompileCommand passes exactly its arguments and environment',
    () async {
      final command = CompileCommand(
        directory: scratch,
        arguments: [
          probe,
          '-c',
          '-O3',
          '-I',
          'src',
          'src/parser.c',
          '-o',
          'x.o',
        ],
        output: 'x.o',
        environment: const {'PATH': '/usr/bin:/bin', 'TMPDIR': '/tmp/x/'},
      );

      await runCompileCommand(command);

      final [argv, environ] = File(
        p.join(scratch, 'x.o'),
      ).readAsStringSync().split('\n');
      check(argv.split('\x00')..removeLast()).deepEquals(command.arguments);
      check(
        environ.split('\x00')..removeLast(),
      ).unorderedEquals(['PATH=/usr/bin:/bin', 'TMPDIR=/tmp/x/']);
    },
  );

  test(
    'runCompileCommand reports a failing compiler with its output',
    () async {
      final command = CompileCommand(
        directory: scratch,
        arguments: [probe, '-c'],
        output: 'y.o',
        environment: const {'PATH': '/usr/bin:/bin'},
      );

      await check(runCompileCommand(command)).throws<CompilerException>(
        (it) => it
            .has((e) => e.message, 'message')
            .startsWith('y.o: clang exited 2'),
      );
    },
  );
}
