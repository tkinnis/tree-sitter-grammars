/// Writes `output/build_info.json` and checks that the flags it records are
/// the flags every compiler invocation in `build/compile_commands.json`
/// passed.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'compiler.dart';
import 'toolchain.dart';

/// This repository's canonical URL, which names the archive's origin.
const repositoryUrl = 'https://github.com/tkinnis/tree-sitter-grammars';

/// The only variables a compiler invocation may see.
const allowedCompilerVariables = {'PATH', 'TMPDIR', 'DEVELOPER_DIR'};

/// The contents of `output/build_info.json`.
///
/// [sources] records each source bundle the build compiled from, by
/// repository name, as `bundleRecord` writes it.
Map<String, Object?> buildInfo({
  required String? release,
  required Toolchain toolchain,
  required Compiler compiler,
  required BuildFlags flags,
  required String repositoryCommit,
  required bool repositoryDirty,
  required int languageVersion,
  required int minCompatibleLanguageVersion,
  required Map<String, Map<String, Object?>> sources,
}) => {
  'release': release,
  'platform': 'macos-${toolchain.arch}',
  'deploymentTarget': toolchain.deploymentTarget,
  'repository': {
    'url': repositoryUrl,
    'commit': repositoryCommit,
    'dirty': repositoryDirty,
  },
  'treeSitter': {
    'tag': toolchain.treeSitterTag,
    'commit': toolchain.treeSitterCommit,
    'languageVersion': languageVersion,
    'minCompatibleLanguageVersion': minCompatibleLanguageVersion,
  },
  'treeSitterCli': {
    'version': toolchain.cliVersion,
    'sha256': toolchain.cliSha256,
  },
  'toolchain': {
    'clang': compiler.version,
    'clangPath': compiler.path,
    'sdk': compiler.sdkVersion,
    'sdkBuild': compiler.sdkBuildVersion,
    'sdkPath': compiler.sdkPath,
    'flags': {
      'workingDirectoryPlaceholder': workingDirectoryPlaceholder,
      'runtime': flags.runtime,
      'grammarCompile': flags.grammarCompile,
      'grammarLink': flags.grammarLink,
    },
  },
  'sources': sources,
};

/// Encodes [info] as `output/build_info.json` is written.
String encodeBuildInfo(Map<String, Object?> info) =>
    '${const JsonEncoder.withIndent('  ').convert(info)}\n';

/// Encodes [commands] as `build/compile_commands.json` is written.
String encodeCompileCommands(List<CompileCommand> commands) {
  final json = [for (final command in commands) command.toJson()];
  return '${const JsonEncoder.withIndent('  ').convert(json)}\n';
}

/// Parses `build/compile_commands.json`.
List<CompileCommand> parseCompileCommands(String json) => [
  for (final entry in jsonDecode(json) as List)
    CompileCommand.fromJson(entry as Map<String, Object?>),
];

/// Every way [commands] depart from the flags [info] records; empty when
/// each invocation passed exactly the recorded flags.
///
/// The runtime and grammar compile lists must each pass `-O3` once and no
/// other optimisation level; the link list, which compiles nothing, passes
/// none. No list may define `NDEBUG`. The runtime must have one invocation
/// and each of [grammarNames] one link, every object a link names must have
/// been compiled, and no invocation may see a variable outside
/// [allowedCompilerVariables].
List<String> buildFlagProblems(
  Map<String, Object?> info,
  List<CompileCommand> commands,
  Set<String> grammarNames,
) {
  final toolchain = info['toolchain']! as Map<String, Object?>;
  final recorded = (toolchain['flags']! as Map<String, Object?>);
  final clang = toolchain['clangPath']! as String;
  final problems = <String>[
    for (final kind in const ['runtime', 'grammarCompile', 'grammarLink'])
      ..._listProblems(kind, (recorded[kind]! as List).cast<String>()),
  ];
  final compiled = {
    for (final command in commands)
      if (_kind(command.output) == 'grammarCompile')
        p.normalize(p.join(command.directory, command.output)),
  };
  final linked = <String>{};
  var runtimes = 0;
  for (final command in commands) {
    final kind = _kind(command.output);
    final flags = (recorded[kind]! as List).cast<String>();
    final prefix = [clang, ...expandFlags(flags, command.directory)];
    final arguments = command.arguments;
    final head = arguments.take(prefix.length).toList();
    if (!_listEquals(head, prefix)) {
      problems.add(
        '${command.output}: arguments do not start with the '
        'recorded $kind flags',
      );
      continue;
    }
    final tail = arguments.skip(prefix.length).toList();
    final shape = switch (kind) {
      'runtime' => _runtimeTailProblem(tail, command.output),
      'grammarCompile' => _compileTailProblem(tail, command.output),
      _ => _linkTailProblem(tail, command.output),
    };
    if (shape != null) problems.add('${command.output}: $shape');
    final stray = command.environment.keys.where(
      (name) => !allowedCompilerVariables.contains(name),
    );
    if (stray.isNotEmpty) {
      problems.add('${command.output}: environment has ${stray.join(', ')}');
    }
    if (kind == 'runtime') runtimes++;
    if (kind != 'grammarLink') continue;
    linked.add(p.basename(command.output));
    for (final object in tail.where((arg) => arg.endsWith('.o'))) {
      if (!compiled.contains(p.normalize(p.join(command.directory, object)))) {
        problems.add('${command.output}: links $object, never compiled');
      }
    }
  }
  if (runtimes != 1) problems.add('$runtimes runtime invocations, not 1');
  for (final name in grammarNames) {
    if (!linked.contains('lib$name.dylib')) problems.add('$name: never linked');
  }
  if (linked.length != grammarNames.length) {
    problems.add('${linked.length} links for ${grammarNames.length} grammars');
  }
  return problems;
}

/// [buildFlagProblems] for the `build_info.json` at [buildInfoPath] and the
/// `compile_commands.json` at [compileCommandsPath], read back from disk.
List<String> checkRecordedFlags({
  required String buildInfoPath,
  required String compileCommandsPath,
  required Set<String> grammarNames,
}) {
  final info =
      jsonDecode(File(buildInfoPath).readAsStringSync())
          as Map<String, Object?>;
  final commands = parseCompileCommands(
    File(compileCommandsPath).readAsStringSync(),
  );
  return buildFlagProblems(info, commands, grammarNames);
}

String _kind(String output) => p.basename(output) == 'libtree-sitter.dylib'
    ? 'runtime'
    : output.endsWith('.o')
    ? 'grammarCompile'
    : 'grammarLink';

List<String> _listProblems(String kind, List<String> flags) {
  final levels = flags.where((flag) => flag.startsWith('-O')).toList();
  final expected = kind == 'grammarLink' ? const <String>[] : const ['-O3'];
  return [
    if (!_listEquals(levels, expected))
      '$kind flags pass optimisation levels $levels, not $expected',
    for (final flag in flags)
      if (flag.contains('NDEBUG')) '$kind flags pass $flag',
  ];
}

String? _runtimeTailProblem(List<String> tail, String output) =>
    _listEquals(tail, ['lib/src/lib.c', '-o', output])
    ? null
    : 'unexpected arguments ${tail.join(' ')}';

String? _compileTailProblem(List<String> tail, String output) =>
    tail.length == 5 &&
        tail[0] == '-I' &&
        tail[2].endsWith('.c') &&
        tail[3] == '-o' &&
        tail[4] == output
    ? null
    : 'unexpected arguments ${tail.join(' ')}';

String? _linkTailProblem(List<String> tail, String output) {
  final installName = '-Wl,-install_name,@rpath/${p.basename(output)}';
  final objects = tail.length < 4
      ? const <String>[]
      : tail.sublist(1, tail.length - 2);
  return tail.length >= 4 &&
          tail.first == installName &&
          objects.every((object) => object.endsWith('.o')) &&
          tail[tail.length - 2] == '-o' &&
          tail.last == output
      ? null
      : 'unexpected arguments ${tail.join(' ')}';
}

bool _listEquals(List<String> a, List<String> b) =>
    a.length == b.length &&
    [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((same) => same);
