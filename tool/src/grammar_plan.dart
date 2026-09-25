/// Turns `tool/grammars.json` and each extracted grammar's
/// `tree-sitter.json` into the list of grammars the build compiles.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'grammar_pins.dart';

/// Thrown when a grammar's sources do not hold what its entry promises.
final class GrammarPlanException implements Exception {
  const GrammarPlanException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// One grammar to compile, with every path relative to the repository root.
final class GrammarBuild {
  GrammarBuild({
    required this.name,
    required this.entry,
    required this.metadata,
    required this.path,
  });

  /// The language id, which names its dylib and its `queries/` directory.
  final String name;

  /// The grammar's entry in `tool/grammars.json`.
  final Map<String, Object?> entry;

  /// The grammar's object in its `tree-sitter.json`, or [entry] when the
  /// entry names the grammar itself.
  final Map<String, Object?> metadata;

  /// The grammar's directory inside its repository, `.` for the root.
  final String path;

  String get url => entry['url']! as String;
  String get commit => entry['commit']! as String;
  String? get sourceCommit => entry['sourceCommit'] as String?;
  String get license => entry['license']! as String;
  bool get generate => entry['generate'] == true;
  String get repository => repositoryName(url);

  /// The exported C symbol is `tree_sitter_<symbol>`.
  String get symbol => name.replaceAll('-', '_');

  /// The grammar's extracted `src/` directory.
  String get sourceDirectory =>
      p.normalize(p.join('build', 'src', repository, path, 'src'));

  /// Where the CLI writes a generated parser.
  String get generatedDirectory => p.join('build', 'gen', name);

  String get parserSource => generate
      ? p.join(generatedDirectory, 'parser.c')
      : p.join(sourceDirectory, 'parser.c');

  /// Headers for `parser.c`: those beside it.
  String get parserIncludeDirectory =>
      generate ? generatedDirectory : sourceDirectory;

  String get objectDirectory => p.join('build', 'obj', name);

  /// The dylib's directory inside `output/`.
  String get dylibDirectory => p.join('dylibs', name);

  String get dylibFileName => 'lib$name.dylib';
}

/// The grammars [entries] build, in `grammars.json` order, reading each
/// repository's `tree-sitter.json` from [root]`/build/src/<repo>`.
///
/// An entry with a `name` builds that one grammar at its `path`. An entry
/// with `grammars` builds the named grammars of its `tree-sitter.json`, in
/// that file's order. Any other url entry builds every grammar its
/// `tree-sitter.json` lists.
List<GrammarBuild> planGrammars(
  String root,
  List<Map<String, Object?>> entries,
) {
  final builds = <GrammarBuild>[];
  for (final entry in entries) {
    if (entry['url'] is! String) continue;
    if (entry['name'] case final String name) {
      builds.add(GrammarBuild(
        name: name,
        entry: entry,
        metadata: entry,
        path: entry['path'] as String? ?? '.',
      ));
      continue;
    }
    final repository = repositoryName(entry['url']! as String);
    final declared = _treeSitterJsonGrammars(root, repository);
    final selected = (entry['grammars'] as List?)?.cast<String>();
    final chosen = selected == null
        ? declared
        : declared.where((grammar) => selected.contains(grammar['name']));
    if (selected != null && chosen.length != selected.length) {
      throw GrammarPlanException('$repository: tree-sitter.json lacks one of '
          '${selected.join(', ')}');
    }
    for (final grammar in chosen) {
      builds.add(GrammarBuild(
        name: grammar['name']! as String,
        entry: entry,
        metadata: grammar,
        path: grammar['path'] as String? ?? '.',
      ));
    }
  }
  final names = <String>{};
  for (final build in builds) {
    if (!names.add(build.name)) {
      throw GrammarPlanException('${build.name}: built by two entries');
    }
  }
  return builds;
}

List<Map<String, Object?>> _treeSitterJsonGrammars(
  String root,
  String repository,
) {
  final file =
      File(p.join(root, 'build', 'src', repository, 'tree-sitter.json'));
  if (!file.existsSync()) {
    throw GrammarPlanException('$repository: no tree-sitter.json at its pin; '
        'give its grammars.json entry a "name"');
  }
  final json = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  final grammars = json['grammars'];
  if (grammars is! List || grammars.isEmpty) {
    throw GrammarPlanException('$repository: tree-sitter.json lists no '
        'grammars');
  }
  return grammars.cast<Map<String, Object?>>();
}

/// The scanner a grammar compiles, or null when it has none.
///
/// Throws a [GrammarPlanException] for a C++ scanner, which the build does
/// not compile.
String? scannerSource(String root, GrammarBuild build) {
  for (final extension in const ['cc', 'cpp']) {
    if (File(p.join(root, build.sourceDirectory, 'scanner.$extension'))
        .existsSync()) {
      throw GrammarPlanException('${build.name}: a C++ scanner '
          '(scanner.$extension) is not supported');
    }
  }
  final scanner = p.join(build.sourceDirectory, 'scanner.c');
  return File(p.join(root, scanner)).existsSync() ? scanner : null;
}

/// Headers for `scanner.c`: the grammar's committed `src/tree_sitter/` when
/// it has one, otherwise the generated ones.
String scannerIncludeDirectory(String root, GrammarBuild build) =>
    Directory(p.join(root, build.sourceDirectory, 'tree_sitter')).existsSync()
        ? build.sourceDirectory
        : build.parserIncludeDirectory;

/// Checks that the extracted sources hold what [build]'s entry promises: a
/// committed `parser.c`, or, for a generated grammar, a `grammar.json` and
/// no committed `parser.c`.
void checkSources(String root, GrammarBuild build) {
  final source = p.join(root, build.sourceDirectory);
  final committedParser = File(p.join(source, 'parser.c')).existsSync();
  if (build.generate) {
    if (committedParser) {
      throw GrammarPlanException('${build.name}: commits src/parser.c, so it '
          'must not be generated; remove "generate" from its entry');
    }
    if (!File(p.join(source, 'grammar.json')).existsSync()) {
      throw GrammarPlanException('${build.name}: no src/grammar.json to '
          'generate from');
    }
  } else if (!committedParser) {
    throw GrammarPlanException('${build.name}: no src/parser.c at '
        '${build.commit}');
  }
}

/// The `LANGUAGE_VERSION` a generated `parser.c` declares: its ABI.
int parserAbi(String parserSource) {
  final match = RegExp(r'^#define LANGUAGE_VERSION (\d+)$', multiLine: true)
      .firstMatch(File(parserSource).readAsStringSync());
  if (match == null) {
    throw GrammarPlanException('$parserSource declares no LANGUAGE_VERSION');
  }
  return int.parse(match.group(1)!);
}
