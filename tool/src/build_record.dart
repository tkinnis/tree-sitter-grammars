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
/// [grammarFlags] records, by grammar, the flags each of its invocations
/// passes beyond the shared lists: [grammarSourceFlags] by source file
/// name, and [grammarLinkFlags] under `link`. [sources] records each
/// source bundle the build compiled from, by repository name, as
/// `bundleRecord` writes it; [generated] each bundle of generated sources,
/// by grammar, as `generatedRecord` writes it; [packingTools] the versions
/// `packingToolVersions` reads of the git, gzip and tar that write the
/// bundles and the archive.
Map<String, Object?> buildInfo({
  required String? release,
  required Toolchain toolchain,
  required Compiler compiler,
  required BuildFlags flags,
  required Map<String, Map<String, List<String>>> grammarFlags,
  required String repositoryCommit,
  required bool repositoryDirty,
  required int languageVersion,
  required int minCompatibleLanguageVersion,
  required Map<String, Map<String, Object?>> sources,
  required Map<String, Map<String, Object?>> generated,
  required Map<String, String> packingTools,
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
    'git': packingTools['git'],
    'gzip': packingTools['gzip'],
    'tar': packingTools['tar'],
    'flags': {
      'workingDirectoryPlaceholder': workingDirectoryPlaceholder,
      'runtime': flags.runtime,
      'grammarCompile': flags.grammarCompile,
      'grammarLink': flags.grammarLink,
      'grammars': grammarFlags,
    },
  },
  'sources': sources,
  'generated': generated,
};

/// Every problem with the `repository` [info] records; empty when it names
/// this repository at a 40-hex commit and, for a release, a working tree
/// that was clean.
///
/// A release reads this repository's files from its commit, so a working
/// tree that changed while it ran never reaches the archive; a release
/// recorded as built from a dirty tree is refused all the same, since the
/// tools that checked it ran from that tree.
List<String> repositoryRecordProblems(Map<String, Object?> info) {
  final repository = info['repository'];
  if (repository is! Map<String, Object?>) {
    return ['build_info.json records no repository'];
  }
  final commit = repository['commit'];
  final dirty = repository['dirty'];
  return [
    if (repository['url'] != repositoryUrl)
      'build_info.json names the repository ${repository['url']}, not '
          '$repositoryUrl',
    if (commit is! String || !RegExp(r'^[0-9a-f]{40}$').hasMatch(commit))
      'build_info.json records no 40-hex repository commit',
    if (dirty is! bool)
      'build_info.json does not record whether the working tree was dirty',
    if (info['release'] is String && dirty != false)
      'build_info.json records the release ${info['release']} as built from '
          'a dirty working tree',
  ];
}

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
/// none. No list may define `NDEBUG`. Each grammar compile and link must
/// pass, after its shared list, exactly the flags `flags.grammars` records
/// of its grammar and source, which name no optimisation level and do not
/// define `NDEBUG` either, and every one of those records must have been
/// passed. The runtime must have one invocation and each of [grammarNames]
/// one link, every object a link names must have been compiled, and no
/// invocation may see a variable outside [allowedCompilerVariables].
List<String> buildFlagProblems(
  Map<String, Object?> info,
  List<CompileCommand> commands,
  Set<String> grammarNames,
) {
  final toolchain = info['toolchain']! as Map<String, Object?>;
  final recorded = (toolchain['flags']! as Map<String, Object?>);
  final clang = toolchain['clangPath']! as String;
  final grammars = _grammarRecords(recorded['grammars']);
  final problems = <String>[
    for (final kind in const ['runtime', 'grammarCompile', 'grammarLink'])
      ..._listProblems(kind, (recorded[kind]! as List).cast<String>()),
    if (grammars == null) 'build_info.json records no flags of each grammar',
    for (final MapEntry(key: name, value: own) in {...?grammars}.entries)
      for (final MapEntry(key: invocation, value: flags) in own.entries)
        for (final flag in flags)
          if (flag.startsWith('-O') || flag.contains('NDEBUG'))
            '$name: its $invocation flags pass $flag',
    for (final name in {...?grammars?.keys}.difference(grammarNames))
      '$name: flags recorded for a grammar the build does not compile',
    if (grammars != null)
      for (final name in grammarNames.difference(grammars.keys.toSet()))
        '$name: build_info.json records no flags of its own',
  ];
  final compiled = {
    for (final command in commands)
      if (_kind(command.output) == 'grammarCompile')
        p.normalize(p.join(command.directory, command.output)),
  };
  final passed = <String>{};
  final linked = <String>{};
  var runtimes = 0;
  for (final command in commands) {
    final kind = _kind(command.output);
    final grammar = p.basename(p.dirname(command.output));
    final invocation = kind == 'grammarCompile'
        ? '${p.basenameWithoutExtension(command.output)}.c'
        : 'link';
    final own = kind == 'runtime'
        ? const <String>[]
        : grammars?[grammar]?[invocation];
    if (own == null) {
      problems.add(
        '${command.output}: build_info.json records no $invocation flags '
        'of $grammar',
      );
      continue;
    }
    if (kind != 'runtime') passed.add('$grammar $invocation');
    final flags = (recorded[kind]! as List).cast<String>();
    final prefix = [clang, ...expandFlags(flags, command.directory), ...own];
    final arguments = command.arguments;
    final head = arguments.take(prefix.length).toList();
    if (!_listEquals(head, prefix)) {
      problems.add(
        '${command.output}: arguments do not start with the '
        'recorded $kind flags and its own',
      );
      continue;
    }
    final tail = arguments.skip(prefix.length).toList();
    final shape = switch (kind) {
      'runtime' => _runtimeTailProblem(tail, command.output),
      'grammarCompile' => _compileTailProblem(tail, command.output, invocation),
      _ => _linkTailProblem(own, tail, command.output),
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
  for (final MapEntry(key: name, value: own) in {...?grammars}.entries) {
    for (final invocation in own.keys) {
      if (!passed.contains('$name $invocation')) {
        problems.add('$name: no invocation passed its $invocation flags');
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

/// `flags.grammars` of `build_info.json`, or null when it is not a map of
/// each grammar to its lists of flags.
Map<String, Map<String, List<String>>>? _grammarRecords(Object? value) {
  if (value is! Map<String, Object?>) return null;
  final records = <String, Map<String, List<String>>>{};
  for (final MapEntry(key: name, value: own) in value.entries) {
    if (own is! Map<String, Object?>) return null;
    records[name] = {};
    for (final MapEntry(key: invocation, value: flags) in own.entries) {
      if (flags is! List || flags.any((flag) => flag is! String)) return null;
      records[name]![invocation] = flags.cast<String>();
    }
  }
  return records;
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

String? _compileTailProblem(List<String> tail, String output, String source) =>
    tail.length == 3 &&
        p.basename(tail[0]) == source &&
        tail[1] == '-o' &&
        tail[2] == output
    ? null
    : 'unexpected arguments ${tail.join(' ')}';

/// Whether a link passing [own] flags and then [tail] writes [output]
/// under its own install name from objects only; the problem, or null.
String? _linkTailProblem(List<String> own, List<String> tail, String output) {
  final installName = '-Wl,-install_name,@rpath/${p.basename(output)}';
  final objects = tail.length < 3
      ? const <String>[]
      : tail.sublist(0, tail.length - 2);
  if (!own.contains(installName)) {
    return 'its recorded flags name no install name $installName';
  }
  return tail.length >= 3 &&
          objects.every((object) => object.endsWith('.o')) &&
          tail[tail.length - 2] == '-o' &&
          tail.last == output
      ? null
      : 'unexpected arguments ${tail.join(' ')}';
}

bool _listEquals(List<String> a, List<String> b) =>
    a.length == b.length &&
    [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((same) => same);
