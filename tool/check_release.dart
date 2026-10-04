/// Checks a built `output/` the way the editor will use it: through the
/// tree-sitter runtime it ships, loaded with `dart:ffi`.
///
/// Usage:
///
/// ```sh
/// dart run tool/check_release.dart [<output>] [--against=<archive>]
/// ```
///
/// `<output>` defaults to `output/`. Every one of these must hold, or the
/// check exits 1 after listing each failure:
///
/// - `build_info.json` names this repository at a 40-hex commit and, when
///   it records a release, a clean working tree.
/// - Every source bundle in `<output>/sources/` has the sha256
///   `build_info.json` records and names its pinned commit, every bundle
///   of generated sources has its recorded sha256, and `sources/` holds
///   exactly the bundles of the runtime and the grammars
///   `tool/grammars.json` pins, and of the grammars it generates.
/// - `build_info.json` records beside each bundle exactly the patches
///   `tool/grammars.json` lists for it, in order, each with the sha256 of
///   the committed patch under `patches/`, and the `patchedSha256` the
///   entry records.
/// - `libtree-sitter.dylib` exports every function the runtime's `api.h`
///   declares, apart from the three it defines only with its wasm feature.
/// - `manifest.json` holds exactly the entries `tool/grammars.json` plans,
///   each of the kind it plans (a compiled grammar, planned as the build
///   plans it from each bundle's `tree-sitter.json`, a query-only language
///   or a no-op one), and every compiled grammar's entry names what the
///   checks below read.
/// - The runtime and every grammar library is a thin binary of the
///   toolchain's architecture with its `minos`, an `@rpath` install name
///   and no dependency beyond `libSystem`.
/// - `build_info.json` records the language versions the runtime's
///   `api.h` defines, and `ts_parser_set_language` accepts every grammar,
///   found through its `config.json` `symbol`, whose
///   `ts_language_abi_version` lies between them.
/// - Every query file of every grammar, composed with what its
///   `; inherits:` line names as the editor composes it, compiles with
///   `ts_query_new`; every language such a line names holds a file of the
///   same type, tsx's `locals.scm` naming `jsx` apart; and every
///   query-only file is read by one of those compositions.
/// - Every composition reads as the patterns `ts_query_new` counts in it,
///   and every pattern of a composed `injections.scm` captures
///   `@injection.content` and names a language, by an
///   `@injection.language` capture or a `#set! injection.language`
///   directive, in every grammar but those `injectionsNamingNoLanguage`
///   lists, each of which holds at least one pattern naming none.
/// - Every source under `test/outline/<grammar>/` parses with no error or
///   missing node, and the outline of the definitions the grammar's
///   composed `tags.scm` finds in it, nested by range as the editor nests
///   its outline, is the `.outline` file beside it, line for line.
/// - Every source under `test/tests/<grammar>/` parses with no error or
///   missing node, and what the grammar's composed `tests.scm` says
///   encloses each test in it, as the editor reads it, is the `.tests`
///   file beside it, line for line: each test's line and the names of the
///   groups around it, or why they are withheld.
/// - Every source under `test/injections/<grammar>/` parses with no error
///   or missing node, and what the grammar's composed `injections.scm`
///   injects in it, as the editor injects it, is the `.injections` file
///   beside it, line for line: each injection's language, ` combined`
///   when its pattern sets `injection.combined`, and the whole text of the
///   node it captures as `@injection.content`, JSON-encoded.
/// - Every source under `test/highlights/<grammar>/` parses with no error
///   or missing node, and what the grammar's composed `highlights.scm`
///   draws in it, the latest pattern's capture over each span, is the
///   `.highlights` file beside it, line for line: each span's capture and
///   its text, JSON-encoded.
/// - Every source under `test/crashes/<grammar>/` parses with the grammar,
///   and parses again after an edit, in a process of its own running
///   `tool/parse_input.dart`, which exits 0 within `parseProcessTimeout`: no
///   scanner aborts the process or crashes it on input it cannot hold.
/// - `THIRD_PARTY_NOTICES.md` is the committed text and names the runtime,
///   every source bundle's commit, every shipped query file and the
///   licences the archive has to carry.
///
/// `--against=<archive>` then compares the grammars of another extracted
/// archive with these, both under this runtime: every example of each
/// grammar's test corpus and every highlight test input from the pinned
/// sources is parsed with both, tsx parsing TypeScript's and JavaScript's
/// as well, and each difference in the tree, or in the captures of a query
/// file both archives carry, is printed. A grammar pinned on a deploy
/// branch is tested with the tests of its `sourceCommit`, read from its
/// object store under `grammars/`. The other archive's grammars parse in
/// processes of their own running `tool/parse_compared.dart`, compiled to
/// kernel once per run, so an input a scanner there aborts or crashes on,
/// or parses for longer than `parseProcessTimeout`, ends only that
/// process: it is printed as one the old release crashes on, with the
/// signal and what the process wrote to stderr, and the comparison goes on
/// from the input after it. Each process writes its parses to a file of
/// its own, leaving stdout to the scanner, and first names the query files
/// it compiled, which must be the files this process compiles of that
/// grammar. Each grammar is compared once its processes are done, while
/// those of the grammars after it run. A match counts only
/// when its pattern's text predicates hold: `#eq?`, `#match?` and
/// `#any-of?` with their `not-` and `any-` forms, evaluated as tree-sitter
/// documents them, a `#match?` pattern read as a Dart regular expression;
/// and its ancestry predicates, `#has-ancestor?` and `#has-parent?` with
/// their `not-` forms, read off the tree as the editor reads them. The
/// same predicates decide the matches of every outline, injection and
/// highlight test. Every capture carries its pattern's other predicates
/// and directives, `#set!` among them, as text, so a changed regular
/// expression, `#set!` value or other directive is a difference wherever
/// the inputs reach it. Every grammar with no inputs is listed, since the
/// comparison cannot vouch for it; the comparison fails only when the
/// other archive's manifest pins one of those at another commit, when a
/// process of the other archive's grammar fails to start or ends before
/// it is ready to parse, or when it names other query files than this
/// process compiles.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'src/build_record.dart';
import 'src/generated_sources.dart';
import 'src/git.dart';
import 'src/grammar_pins.dart';
import 'src/grammar_plan.dart';
import 'src/grammar_sources.dart';
import 'src/macho.dart';
import 'src/notices.dart';
import 'src/parse_process.dart';
import 'src/pool.dart';
import 'src/release_check.dart';
import 'src/source_bundles.dart';
import 'src/source_patches.dart';
import 'src/toolchain.dart';
import 'src/tree_sitter_cli.dart';
import 'src/tree_sitter_ffi.dart';

const _usage =
    'usage: dart run tool/check_release.dart [<output>] '
    '[--against=<archive>]';

/// One compiled grammar of an archive.
typedef _Grammar = ({
  String name,
  String directory,
  String symbol,
  String url,
  String commit,
  String? sourceCommit,
  String path,
  List<String> extensions,
});

Future<void> main(List<String> args) async {
  String? output;
  String? against;
  for (final arg in args) {
    if (arg.startsWith('--against=') && against == null) {
      against = arg.substring('--against='.length);
    } else if (!arg.startsWith('-') && output == null) {
      output = arg;
    } else {
      stderr.writeln(_usage);
      exit(64);
    }
  }
  final root = p.dirname(p.dirname(p.fromUri(Platform.script)));
  final directory = p.normalize(p.absolute(output ?? p.join(root, 'output')));
  final scratch = Directory.systemTemp.createTempSync('check_release');
  try {
    final problems = <String>[];
    final (:runtime, :grammars, :sources) = await _check(
      root,
      directory,
      scratch.path,
      problems,
      unpackGrammars: against != null,
    );
    if (problems.isNotEmpty) {
      stderr.writeln('\n✗ ${problems.length} problems:');
      for (final problem in problems) {
        stderr.writeln('  $problem');
      }
      exitCode = 1;
      return;
    }
    print('✓ $directory is releasable');
    if (against != null) {
      await _compare(
        runtime!,
        p.join(directory, 'libtree-sitter.dylib'),
        grammars,
        p.normalize(p.absolute(against)),
        sourceRoot: sources,
        root: root,
        scratch: scratch.path,
      );
    }
  } on Exception catch (error) {
    stderr.writeln('✗ $error');
    exitCode = 1;
  } finally {
    scratch.deleteSync(recursive: true);
  }
}

Map<String, Object?> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;

/// Runs every check on [output], adding each failure to [problems], and
/// returns the opened runtime, the compiled grammars and the directory the
/// grammar bundles were unpacked into under [scratch].
Future<({TreeSitterRuntime? runtime, List<_Grammar> grammars, String sources})>
_check(
  String root,
  String output,
  String scratch,
  List<String> problems, {
  required bool unpackGrammars,
}) async {
  final toolchain = Toolchain.load(root);
  final entries = parseGrammars(
    File(p.join(root, 'tool', 'grammars.json')).readAsStringSync(),
  );
  final info = _json(p.join(output, 'build_info.json'));
  final manifest = _json(p.join(output, 'manifest.json'));
  problems.addAll(repositoryRecordProblems(info));
  final treeSitter = info['treeSitter']! as Map<String, Object?>;
  if (treeSitter['tag'] != toolchain.treeSitterTag ||
      treeSitter['commit'] != toolchain.treeSitterCommit) {
    problems.add(
      'build_info.json names tree-sitter ${treeSitter['tag']} '
      '(${treeSitter['commit']}); toolchain.json pins '
      '${toolchain.treeSitterTag} (${toolchain.treeSitterCommit})',
    );
  }

  final sourceRoot = p.join(scratch, 'src');
  await _checkSources(
    root,
    output,
    toolchain,
    entries,
    info,
    sourceRoot,
    problems,
    unpackGrammars: unpackGrammars,
  );

  final runtimePath = p.join(output, 'libtree-sitter.dylib');
  final runtime = TreeSitterRuntime.open(runtimePath);
  _checkExports(runtime, p.join(sourceRoot, 'tree-sitter'), problems);
  final languageVersions = _checkLanguageVersions(
    p.join(sourceRoot, 'tree-sitter'),
    treeSitter,
    problems,
  );

  List<GrammarBuild> plan = const [];
  try {
    plan = planGrammars(root, entries, sourceRoot: sourceRoot);
  } on GrammarPlanException catch (error) {
    problems.add('grammars.json: $error');
  }
  await _checkGenerated(output, info, plan, problems);
  _checkBundleFiles(output, toolchain, entries, plan, problems);
  final grammars = _checkManifest(output, manifest, entries, plan, problems);
  await _checkLibraries(runtimePath, grammars, toolchain, problems);
  final languages = _checkGrammars(
    runtime,
    grammars,
    languageVersions,
    problems,
  );
  _checkQueries(runtime, output, grammars, languages, problems);
  _checkQueryTests(root, runtime, grammars, languages, problems);
  await _checkCrashTests(root, runtimePath, grammars, languages, problems);
  _checkNotices(root, output, info, problems);
  return (runtime: runtime, grammars: grammars, sources: sourceRoot);
}

/// Checks every bundle against `build_info.json` and the pins, and the
/// patches it records beside each against those `tool/grammars.json` lists
/// and the committed patches under [root], and unpacks the runtime's into
/// [sourceRoot], with every grammar's when [unpackGrammars]; of a grammar
/// bundle not unpacked, only its `tree-sitter.json`, which plans its
/// grammars, is written there.
Future<void> _checkSources(
  String root,
  String output,
  Toolchain toolchain,
  List<Map<String, Object?>> entries,
  Map<String, Object?> info,
  String sourceRoot,
  List<String> problems, {
  required bool unpackGrammars,
}) async {
  final recorded = info['sources'];
  if (recorded is! Map<String, Object?>) {
    problems.add('build_info.json records no sources');
    return;
  }
  final pinned = pinnedSources(toolchain, entries);
  final bundles = p.join(output, sourcesDirectoryName);
  var good = 0;
  for (final source in pinned) {
    try {
      await checkRecordedBundle(bundles, source, recorded);
      problems.addAll([
        for (final problem in await patchRecordProblems(
          source,
          recorded[source.name]! as Map<String, Object?>,
          root,
        ))
          '${source.name}: $problem',
      ]);
      if (!unpackGrammars && source.url != runtimeRepositoryUrl) {
        final plan = await bundleFile(
          p.join(bundles, source.bundleName),
          'tree-sitter.json',
        );
        if (plan != null) {
          File(p.join(sourceRoot, source.name, 'tree-sitter.json'))
            ..parent.createSync(recursive: true)
            ..writeAsStringSync(plan);
        }
        good++;
        continue;
      }
      await unpackBundle(
        p.join(bundles, source.bundleName),
        p.join(sourceRoot, source.name),
      );
      good++;
    } on Exception catch (error) {
      problems.add('${source.name}: $error');
    }
  }
  final extra = recorded.keys.toSet().difference({
    for (final source in pinned) source.name,
  });
  if (extra.isNotEmpty) {
    problems.add('build_info.json records unpinned sources $extra');
  }
  print(
    'sources: $good/${pinned.length} bundles carry their recorded sha256 '
    'and pinned commit',
  );
}

/// Checks the bundle of generated sources of every grammar of [plan] that
/// is generated against the `generated` record of `build_info.json`
/// [info]: it must be the one bundle recorded for it, with its sha256.
Future<void> _checkGenerated(
  String output,
  Map<String, Object?> info,
  List<GrammarBuild> plan,
  List<String> problems,
) async {
  final recorded = info['generated'];
  if (recorded is! Map<String, Object?>) {
    problems.add('build_info.json records no generated sources');
    return;
  }
  final generated = plan.where((build) => build.generate).toList();
  var good = 0;
  for (final build in generated) {
    try {
      await checkRecordedGenerated(
        p.join(output, sourcesDirectoryName),
        build,
        recorded,
      );
      good++;
    } on Exception catch (error) {
      problems.add('$error');
    }
  }
  final extra = recorded.keys.toSet().difference({
    for (final build in generated) build.name,
  });
  if (extra.isNotEmpty) {
    problems.add('build_info.json records ungenerated grammars $extra');
  }
  print(
    'generated: $good/${generated.length} bundles of generated sources '
    'carry their recorded sha256',
  );
}

/// Requires `sources/` in [output] to hold exactly the source bundles of
/// the pins and the generated bundles of [plan].
void _checkBundleFiles(
  String output,
  Toolchain toolchain,
  List<Map<String, Object?>> entries,
  List<GrammarBuild> plan,
  List<String> problems,
) {
  final expected = {
    for (final source in pinnedSources(toolchain, entries)) source.bundleName,
    for (final build in plan)
      if (build.generate) generatedBundleName(build.name, build.commit),
  };
  final directory = Directory(p.join(output, sourcesDirectoryName));
  final found = {
    if (directory.existsSync())
      for (final entity in directory.listSync()) p.basename(entity.path),
  };
  for (final name in found.difference(expected)) {
    problems.add('$sourcesDirectoryName/$name is no bundle of this build');
  }
  for (final name in expected.difference(found)) {
    problems.add('$sourcesDirectoryName/ holds no $name');
  }
}

/// Checks that every entry of [manifest] is the kind of entry `grammars.json`
/// [entries] plan for its name, [plan] listing the compiled grammars, and
/// returns those.
///
/// An entry with a `dylib_dir` is a compiled grammar's and must name its
/// `source` (url, commit and path) and its `extensions`; one with
/// `queryOnly` is a query-only language's; any other is a no-op
/// language's. Each must be the kind `grammars.json` plans for its name.
/// Every name planned and missing, and every entry unplanned or
/// unreadable, is a problem, so no entry drops out of the checks that
/// follow unseen.
List<_Grammar> _checkManifest(
  String output,
  Map<String, Object?> manifest,
  List<Map<String, Object?>> entries,
  List<GrammarBuild> plan,
  List<String> problems,
) {
  final expected = <String, String>{
    for (final entry in entries)
      if (entry['noop'] == true)
        entry['name']! as String: 'no-op'
      else if (entry['queryOnly'] == true)
        entry['name']! as String: 'query-only',
  };
  for (final build in plan) {
    expected[build.name] = 'grammar';
  }
  final grammars = <_Grammar>[];
  var good = 0;
  for (final MapEntry(key: name, value: entry) in manifest.entries) {
    final kind = switch (entry) {
      {'queryOnly': true} => 'query-only',
      {'dylib_dir': _} => 'grammar',
      _ => 'no-op',
    };
    if (expected[name] != kind) {
      problems.add(
        'manifest.json: $name is a $kind entry; grammars.json plans '
        '${expected[name] ?? 'no entry'} for it',
      );
      continue;
    }
    if (kind != 'grammar') {
      good++;
      continue;
    }
    if (entry case {
      'dylib_dir': final String directory,
      'source':
          {
            'url': final String url,
            'commit': final String commit,
            'path': final String path,
          } &&
          final Map<String, Object?> source,
      'extensions': final List<Object?> extensions,
    }) {
      final config = File(p.join(output, directory, 'config.json'));
      grammars.add((
        name: name,
        directory: p.join(output, directory),
        symbol: config.existsSync()
            ? _json(config.path)['symbol'] as String? ?? ''
            : '',
        url: url,
        commit: commit,
        sourceCommit: source['sourceCommit'] as String?,
        path: path,
        extensions: extensions.cast<String>(),
      ));
      good++;
    } else {
      problems.add(
        'manifest.json: $name has no dylib_dir, source url, commit and path, '
        'or extensions to check it by',
      );
    }
  }
  final missing = expected.keys.where((name) => !manifest.containsKey(name));
  for (final name in missing) {
    problems.add('manifest.json has no entry for $name');
  }
  print(
    'manifest: $good/${expected.length} entries are what grammars.json '
    'plans, ${grammars.length} of them compiled grammars',
  );
  return grammars;
}

void _checkExports(
  TreeSitterRuntime runtime,
  String runtimeSource,
  List<String> problems,
) {
  final header = File(
    p.join(runtimeSource, 'lib', 'include', 'tree_sitter', 'api.h'),
  );
  if (!header.existsSync()) {
    problems.add('the runtime bundle holds no lib/include/tree_sitter/api.h');
    return;
  }
  final declared = apiFunctions(header.readAsStringSync());
  final expected = declared.where((f) => !wasmOnlyFunctions.contains(f));
  final missing = expected.where((f) => !runtime.exports(f)).toList();
  for (final function in missing) {
    problems.add('libtree-sitter.dylib does not export $function');
  }
  print(
    'runtime: ${expected.length - missing.length}/${expected.length} '
    'api.h functions exported (${declared.length} declared; '
    '${declared.length - expected.length} need the wasm feature)',
  );
}

Future<void> _checkLibraries(
  String runtimePath,
  List<_Grammar> grammars,
  Toolchain toolchain,
  List<String> problems,
) async {
  final expectations = [
    LibraryExpectation(
      path: runtimePath,
      installName: '@rpath/libtree-sitter.dylib',
      exportedSymbols: const ['_ts_parser_new'],
    ),
    for (final grammar in grammars)
      LibraryExpectation(
        path: p.join(grammar.directory, 'lib${grammar.name}.dylib'),
        installName: '@rpath/lib${grammar.name}.dylib',
        exportedSymbols: ['_tree_sitter_${grammar.symbol}'],
      ),
  ];
  var good = 0;
  for (final expectation in expectations) {
    final found = await libraryProblems(expectation, toolchain);
    problems.addAll(found);
    if (found.isEmpty) good++;
  }
  print(
    'libraries: $good/${expectations.length} thin ${toolchain.arch}, '
    'minos ${toolchain.deploymentTarget}, @rpath install names, '
    'libSystem only',
  );
}

/// The language versions the runtime's `api.h` under [runtimeSource]
/// defines, after requiring [treeSitter], the `treeSitter` object of
/// `build_info.json`, to record the same; null, with a problem, when
/// `api.h` defines none.
({int current, int minCompatible})? _checkLanguageVersions(
  String runtimeSource,
  Map<String, Object?> treeSitter,
  List<String> problems,
) {
  final header = File(
    p.join(runtimeSource, 'lib', 'include', 'tree_sitter', 'api.h'),
  );
  final ({int current, int minCompatible}) versions;
  try {
    versions = apiLanguageVersions(header.readAsStringSync());
  } on Exception catch (error) {
    problems.add('the runtime\'s language versions: $error');
    return null;
  }
  if (treeSitter['languageVersion'] != versions.current ||
      treeSitter['minCompatibleLanguageVersion'] != versions.minCompatible) {
    problems.add(
      'build_info.json records language versions '
      '${treeSitter['minCompatibleLanguageVersion']} to '
      '${treeSitter['languageVersion']}; the runtime\'s api.h defines '
      '${versions.minCompatible} to ${versions.current}',
    );
  }
  return versions;
}

/// Opens every grammar and returns its language by name.
///
/// Each grammar's language ABI must lie in the range of [languageVersions],
/// which the runtime's `api.h` defines.
Map<String, Pointer<Void>> _checkGrammars(
  TreeSitterRuntime runtime,
  List<_Grammar> grammars,
  ({int current, int minCompatible})? languageVersions,
  List<String> problems,
) {
  final languages = <String, Pointer<Void>>{};
  final abis = <int>{};
  for (final grammar in grammars) {
    final Pointer<Void> language;
    try {
      language = openLanguage(
        p.join(grammar.directory, 'lib${grammar.name}.dylib'),
        grammar.symbol,
      );
    } on Object catch (error) {
      problems.add('${grammar.name}: $error');
      continue;
    }
    final abi = runtime.abiVersion(language);
    abis.add(abi);
    if (languageVersions case (
      :final current,
      :final minCompatible,
    ) when abi < minCompatible || abi > current) {
      problems.add(
        '${grammar.name}: language ABI $abi is outside '
        '$minCompatible..$current',
      );
    } else if (!runtime.acceptsLanguage(language)) {
      problems.add('${grammar.name}: ts_parser_set_language refused it');
    } else {
      languages[grammar.name] = language;
    }
  }
  final sorted = abis.toList()..sort();
  print(
    'grammars: ${languages.length}/${grammars.length} accepted by '
    'ts_parser_set_language, ABI ${sorted.join(', ')}',
  );
  return languages;
}

/// Composes every query file of every grammar as [composeArchiveQueries]
/// does, which lists its problems, and compiles each composition with its
/// grammar's language.
///
/// Each composition must read as the patterns `ts_query_new` counts in
/// it, so [injectionPatternsCapturingNoContent] and
/// [injectionPatternsNamingNoLanguage] read every one of them. Every
/// injection pattern must capture `@injection.content`, and
/// [_checkInjectionLanguages] then holds each grammar's injection patterns
/// to naming a language.
void _checkQueries(
  TreeSitterRuntime runtime,
  String output,
  List<_Grammar> grammars,
  Map<String, Pointer<Void>> languages,
  List<String> problems,
) {
  final grammarAt = {
    for (final grammar in grammars) grammar.directory: grammar,
  };
  final queries = composeArchiveQueries(output, grammarAt.keys, problems);
  var compiled = 0;
  var patterns = 0;
  final namingNoLanguage = <String, List<int>>{};
  for (final (:directory, :fileName, :source) in queries.composed) {
    final name = grammarAt[directory]!.name;
    if (fileName == 'injections.scm') {
      final capturingNoContent = injectionPatternsCapturingNoContent(source);
      if (capturingNoContent.isNotEmpty) {
        problems.add(
          '$name/injections.scm: ${capturingNoContent.length} patterns '
          'capture no @injection.content (composed lines '
          '${capturingNoContent.join(', ')})',
        );
      }
      final lines = injectionPatternsNamingNoLanguage(source);
      if (lines.isNotEmpty) namingNoLanguage[name] = lines;
    }
    final language = languages[name];
    if (language == null) continue;
    try {
      final query = runtime.compile(language, source);
      patterns += query.patternCount;
      final read = queryPatterns(source).length;
      if (read != query.patternCount) {
        problems.add(
          '$name/$fileName: read as $read patterns; ts_query_new counts '
          '${query.patternCount}',
        );
      }
      query.delete();
      compiled++;
    } on QueryException catch (error) {
      problems.add(
        '$name/$fileName: $error (composed line '
        '${_lineAt(source, error.byteOffset)})',
      );
    }
  }
  print(
    'queries: $compiled/${queries.fileCount} composed files compile, '
    '$patterns patterns; ${queries.queryOnlyReadCount}/'
    '${queries.queryOnlyCount} query-only files inherited',
  );
  _checkInjectionLanguages(namingNoLanguage, problems);
}

/// Requires the grammars in [namingNoLanguage], each with the composed
/// lines of its injection patterns that name no language, to be exactly
/// [injectionsNamingNoLanguage].
void _checkInjectionLanguages(
  Map<String, List<int>> namingNoLanguage,
  List<String> problems,
) {
  for (final MapEntry(key: name, value: lines) in namingNoLanguage.entries) {
    if (!injectionsNamingNoLanguage.contains(name)) {
      problems.add(
        '$name/injections.scm: ${lines.length} patterns name no language '
        '(composed lines ${lines.join(', ')})',
      );
    }
  }
  for (final name in injectionsNamingNoLanguage) {
    if (!namingNoLanguage.containsKey(name)) {
      problems.add(
        '$name: every injection pattern names a language; take it out of '
        'injectionsNamingNoLanguage',
      );
    }
  }
  final counts = [
    for (final MapEntry(key: name, value: lines) in namingNoLanguage.entries)
      '$name ${lines.length}',
  ]..sort();
  print(
    counts.isEmpty
        ? 'injections: every pattern names a language'
        : 'injections: '
              '${namingNoLanguage.values.fold(0, (a, b) => a + b.length)} '
              'patterns name no language, in ${counts.join(', ')}',
  );
}

/// A kind of query test: every source under `<directory>/<grammar>/`,
/// beside a `<source><suffix>` file whose lines must be what [lines] makes
/// of the matches of the grammar's composed [queryFile] over the source's
/// UTF-8 text.
typedef _QueryTest = ({
  String kind,
  String directory,
  String queryFile,
  String suffix,
  List<String> Function(List<QueryMatch> matches, List<int> text) lines,
});

/// The captures of each of [matches], one list per match.
List<List<Capture>> _capturesOf(List<QueryMatch> matches) => [
  for (final match in matches) match.captures,
];

/// The outline tests, whose `.outline` file is the [outline] of the
/// definitions `tags.scm` finds, the test-structure tests, whose `.tests`
/// file is the [testStructureLines] of what `tests.scm` puts around each
/// test, the injection tests, whose `.injections` file is the
/// [injectionLines] of what `injections.scm` injects, and the highlight
/// tests, whose `.highlights` file is the [highlightLines] of what
/// `highlights.scm` draws.
final _queryTests = <_QueryTest>[
  (
    kind: 'outline',
    directory: 'test/outline',
    queryFile: 'tags.scm',
    suffix: '.outline',
    lines: (matches, text) =>
        outline(tagDefinitions(_capturesOf(matches), text)),
  ),
  (
    kind: 'test-structure',
    directory: 'test/tests',
    queryFile: 'tests.scm',
    suffix: '.tests',
    lines: (matches, text) => testStructureLines(_capturesOf(matches), text),
  ),
  (
    kind: 'injection',
    directory: 'test/injections',
    queryFile: 'injections.scm',
    suffix: '.injections',
    lines: (matches, text) =>
        injectionLines(injections(_capturesOf(matches), text), text),
  ),
  (
    kind: 'highlight',
    directory: 'test/highlights',
    queryFile: 'highlights.scm',
    suffix: '.highlights',
    lines: highlightLines,
  ),
];

/// Runs every test of [_queryTests] in [root].
void _checkQueryTests(
  String root,
  TreeSitterRuntime runtime,
  List<_Grammar> grammars,
  Map<String, Pointer<Void>> languages,
  List<String> problems,
) {
  for (final test in _queryTests) {
    _checkQueryTest(test, root, runtime, grammars, languages, problems);
  }
}

/// Checks every source of [test] in [root] with the composed query file of
/// the grammar its directory names: the source must parse with no error or
/// missing node, and give the lines of the file beside it.
void _checkQueryTest(
  _QueryTest test,
  String root,
  TreeSitterRuntime runtime,
  List<_Grammar> grammars,
  Map<String, Pointer<Void>> languages,
  List<String> problems,
) {
  final (:kind, :directory, :queryFile, :suffix, lines: _) = test;
  final tests = Directory(p.join(root, directory));
  final grammarDirectories = tests.existsSync()
      ? (tests.listSync().whereType<Directory>().toList()
          ..sort((a, b) => a.path.compareTo(b.path)))
      : const <Directory>[];
  var good = 0;
  var total = 0;
  for (final grammarDirectory in grammarDirectories) {
    final name = p.basename(grammarDirectory.path);
    final files = [
      for (final file in grammarDirectory.listSync().whereType<File>())
        if (!p.basename(file.path).startsWith('.')) file.path,
    ];
    final sources = files.where((f) => !f.endsWith(suffix)).toList()..sort();
    for (final orphan in files.where(
      (f) => f.endsWith(suffix) && !sources.contains(p.withoutExtension(f)),
    )) {
      problems.add('${p.relative(orphan, from: root)} has no source');
    }
    total += sources.length;
    final grammar = grammars.where((g) => g.name == name).firstOrNull;
    final language = languages[name];
    if (grammar == null || language == null) {
      problems.add('$directory/$name names no grammar the runtime opens');
      continue;
    }
    final Query query;
    try {
      final source = composeQuery(grammar.directory, queryFile);
      if (source == null) {
        problems.add('$directory/$name: $name has no $queryFile');
        continue;
      }
      query = runtime.compile(language, source);
    } on Exception {
      // _checkQueries lists why the query does not compose or compile.
      continue;
    }
    try {
      for (final source in sources) {
        final problem = _queryTestProblem(
          test,
          runtime,
          language,
          query,
          source,
        );
        if (problem == null) {
          good++;
        } else {
          problems.add('${p.relative(source, from: root)}: $problem');
        }
      }
    } finally {
      query.delete();
    }
  }
  print('$kind tests: $good/$total sources under $directory as expected');
}

/// What is wrong with [source], a source of [test], or null when it parses
/// cleanly with [language] and the lines [test] makes of [query]'s matches
/// are the file beside it.
String? _queryTestProblem(
  _QueryTest test,
  TreeSitterRuntime runtime,
  Pointer<Void> language,
  Query query,
  String source,
) {
  final expected = File('$source${test.suffix}');
  if (!expected.existsSync()) return 'no ${p.basename(expected.path)}';
  final text = File(source).readAsStringSync();
  final (:tree, :matches) = runtime.parseMatches(language, text, query);
  if (tree.contains('(ERROR') || tree.contains('(MISSING')) {
    return 'parses with an error or missing node';
  }
  final found = test.lines(matches, utf8.encode(text));
  final lines = const LineSplitter().convert(expected.readAsStringSync());
  String at(List<String> lines, int index) =>
      index < lines.length ? jsonEncode(lines[index]) : 'nothing';
  for (var index = 0; index < found.length || index < lines.length; index++) {
    if (at(found, index) != at(lines, index)) {
      return '${test.kind} line ${index + 1} is ${at(found, index)}; '
          '${p.basename(expected.path)} has ${at(lines, index)}';
    }
  }
  return null;
}

/// Parses every source under `test/crashes/<grammar>/` in [root] with its
/// grammar, each in a process of its own running `tool/parse_input.dart`
/// against the runtime at [runtimePath], and requires every one to exit 0
/// within [parseProcessTimeout], as [parseProcessProblem] reads its run.
///
/// A scanner that aborts, or writes past the state it is given and
/// crashes, ends only the process parsing that source, so each failure is
/// listed by its source.
Future<void> _checkCrashTests(
  String root,
  String runtimePath,
  List<_Grammar> grammars,
  Map<String, Pointer<Void>> languages,
  List<String> problems,
) async {
  final tests = Directory(p.join(root, 'test', 'crashes'));
  final runs = <(String, _Grammar)>[];
  if (tests.existsSync()) {
    final directories = tests.listSync().whereType<Directory>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final directory in directories) {
      final name = p.basename(directory.path);
      final grammar = grammars.where((g) => g.name == name).firstOrNull;
      if (grammar == null || !languages.containsKey(name)) {
        problems.add('test/crashes/$name names no grammar the runtime opens');
        continue;
      }
      final sources = [
        for (final file in directory.listSync().whereType<File>())
          if (!p.basename(file.path).startsWith('.')) file.path,
      ]..sort();
      for (final source in sources) {
        runs.add((source, grammar));
      }
    }
  }
  final results = await pooled(runs, (run) async {
    final (source, grammar) = run;
    final process = await Process.start(Platform.resolvedExecutable, [
      'run',
      p.join('tool', 'parse_input.dart'),
      runtimePath,
      p.join(grammar.directory, 'lib${grammar.name}.dylib'),
      grammar.symbol,
      source,
    ], workingDirectory: root);
    final errors = readOutput(process.stderr);
    final output = process.stdout.drain<void>();
    int? exitCode;
    try {
      exitCode = await process.exitCode.timeout(parseProcessTimeout);
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
      await process.exitCode;
    }
    await output;
    return parseProcessProblem(exitCode, await errors);
  }, limit: 4);
  for (final (index, (source, _)) in runs.indexed) {
    if (results[index] case final problem?) {
      problems.add('${p.relative(source, from: root)}: $problem');
    }
  }
  print(
    'crash tests: ${results.where((problem) => problem == null).length}/'
    '${runs.length} sources under test/crashes parse and reparse',
  );
}

int _lineAt(String source, int byteOffset) {
  final bytes = utf8.encode(source);
  final end = byteOffset.clamp(0, bytes.length);
  return '\n'.allMatches(utf8.decode(bytes.sublist(0, end))).length + 1;
}

void _checkNotices(
  String root,
  String output,
  Map<String, Object?> info,
  List<String> problems,
) {
  final shipped = File(p.join(output, noticesFileName));
  if (!shipped.existsSync()) {
    problems.add('$output has no $noticesFileName');
    return;
  }
  final text = shipped.readAsStringSync();
  final committed = File(p.join(root, noticesFileName));
  final current =
      committed.existsSync() && committed.readAsStringSync() == text;
  if (!current) {
    problems.add('$noticesFileName in $output is not the committed text');
  }
  final required = [
    'Max Brunsfeld',
    'Unicode, Inc',
    'Regents of the University of California',
    'Apache License',
    (info['treeSitter']! as Map)['tag'] as String,
    for (final record in (info['sources']! as Map).values)
      (record as Map)['commit'] as String,
  ];
  final queryFiles = [
    for (final top in ['dylibs', 'queries'])
      if (Directory(p.join(output, top)).existsSync())
        for (final entity in Directory(
          p.join(output, top),
        ).listSync(recursive: true))
          if (entity is File && entity.path.endsWith('.scm'))
            '`${p.basename(p.dirname(entity.path))}/'
                '${p.basename(entity.path)}`',
  ];
  final missing = [
    for (final needle in [...required, ...queryFiles])
      if (!text.contains(needle)) needle,
  ];
  for (final needle in missing) {
    problems.add('$noticesFileName does not name $needle');
  }
  print(
    'notices: $noticesFileName ${current ? 'is' : 'is not'} the committed '
    'text and names '
    '${required.length + queryFiles.length - missing.length}/'
    '${required.length + queryFiles.length} required texts '
    '(${queryFiles.length} query files)',
  );
}

/// One input a grammar's tests parse.
typedef _Input = ({String label, String text});

/// The grammars whose syntax takes in other grammars', each with those
/// grammars, whose inputs the comparison parses with it as well. TSX is
/// TypeScript with JSX: TypeScript's corpus names tsx in one example, and
/// JavaScript's corpus holds the JSX.
const _alsoParses = {
  'tsx': ['typescript', 'javascript'],
};

/// Compares [grammars] with the same grammars in the archive extracted at
/// [archive], parsing the inputs of the test trees [_testTrees] supplies
/// from [sourceRoot], or from the object stores under [root] into a
/// directory under [scratch]; a grammar in [_alsoParses] parses the inputs
/// of the grammars it names too.
///
/// This archive's grammars parse in this process, under the runtime at
/// [runtimePath] that [runtime] opened. The other archive's parse under the
/// same runtime in processes of their own, four at a time, as [_parseThere]
/// runs them, so a scanner of the other archive that aborts or crashes on
/// an input ends only its process; the input is printed as one the old
/// release crashes on and the comparison goes on. Each grammar is compared
/// as soon as its processes are done, while those of the grammars after it
/// run.
///
/// Lists every grammar with no inputs, which the comparison cannot vouch
/// for, and sets a failing exit code when the other archive's manifest
/// pins one of those at another commit, when a process of the other
/// archive's grammar ends before it is ready to parse, or when it compiles
/// other query files than this process compiles of that grammar.
Future<void> _compare(
  TreeSitterRuntime runtime,
  String runtimePath,
  List<_Grammar> grammars,
  String archive, {
  required String sourceRoot,
  required String root,
  required String scratch,
}) async {
  print('\n── Comparing with $archive under this runtime');
  final testTrees = await _testTrees(
    root,
    grammars,
    sourceRoot,
    p.join(scratch, 'tests'),
  );
  List<_Input> inputsOf(_Grammar owner) =>
      switch (testTrees[repositoryName(owner.url)]) {
        final testTree? => _inputs(owner, grammars, testTree),
        null => const [],
      };
  final pairs = [
    for (final grammar in grammars)
      _pairWith(grammar, archive, [
        ...inputsOf(grammar),
        for (final name in _alsoParses[grammar.name] ?? const <String>[])
          for (final other in grammars.where((g) => g.name == name))
            ...inputsOf(other),
      ]),
  ];
  final parser = await _compileParseCompared(root, scratch);
  final parsedThere = pooledEach(
    pairs,
    (pair) async => pair == null
        ? null
        : await _parseThere(
            pair,
            runtimePath,
            parser,
            p.join(scratch, 'parses'),
          ),
    limit: 4,
  );
  final totals = _Totals();
  for (final (index, grammar) in grammars.indexed) {
    if ((pairs[index], await parsedThere[index]) case (
      final pair?,
      final there?,
    )) {
      _compareGrammar(runtime, archive, pair, there, totals);
    } else {
      print('${grammar.name}: not in $archive');
    }
  }
  totals.report(archive);
}

/// A grammar of this archive beside the same grammar in the other: the
/// other's directory and its grammar's symbol, the query files only one
/// of them carries and those both carry, and the inputs both parse.
typedef _Pair = ({
  _Grammar grammar,
  String theirs,
  String symbol,
  List<String> onlyOurs,
  List<String> onlyTheirs,
  List<String> shared,
  List<_Input> inputs,
});

/// [grammar] beside the same grammar in the archive extracted at
/// [archive], to parse [inputs] with both; null when that archive holds no
/// library of it.
_Pair? _pairWith(_Grammar grammar, String archive, List<_Input> inputs) {
  final theirs = p.join(archive, 'dylibs', grammar.name);
  if (!File(p.join(theirs, 'lib${grammar.name}.dylib')).existsSync()) {
    return null;
  }
  final ourFiles = queryFiles(grammar.directory).toSet();
  final theirFiles = queryFiles(theirs).toSet();
  return (
    grammar: grammar,
    theirs: theirs,
    symbol:
        _json(p.join(theirs, 'config.json'))['symbol'] as String? ??
        grammar.symbol,
    onlyOurs: ourFiles.difference(theirFiles).toList(),
    onlyTheirs: theirFiles.difference(ourFiles).toList(),
    shared: ourFiles.intersection(theirFiles).toList()..sort(),
    inputs: inputs,
  );
}

/// Compiles `tool/parse_compared.dart` in [root] to a kernel file in
/// [scratch] and returns its path, so each process [_parseThere] starts
/// runs it without compiling it again.
///
/// Throws a [ProcessException] when it does not compile.
Future<String> _compileParseCompared(String root, String scratch) async {
  final kernel = p.join(scratch, 'parse_compared.dill');
  final arguments = [
    'compile',
    'kernel',
    '--verbosity=error',
    '--output=$kernel',
    p.join('tool', 'parse_compared.dart'),
  ];
  final result = await Process.run(
    Platform.resolvedExecutable,
    arguments,
    workingDirectory: root,
  );
  if (result.exitCode != 0) {
    throw ProcessException(
      Platform.resolvedExecutable,
      arguments,
      '${result.stdout}${result.stderr}'.trim(),
      result.exitCode,
    );
  }
  return kernel;
}

/// Parses the inputs of [pair] with the other archive's grammar under the
/// runtime at [runtimePath], in processes running [parser], the kernel of
/// `tool/parse_compared.dart`, as [parseInProcesses] runs them, which read
/// the request it writes into a directory of the grammar's own under
/// [scratch] and write their results there.
Future<ProcessParses> _parseThere(
  _Pair pair,
  String runtimePath,
  String parser,
  String scratch,
) {
  final name = pair.grammar.name;
  final directory = p.join(scratch, name);
  final request = File(p.join(directory, 'request.json'))
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(
      jsonEncode({
        'runtime': runtimePath,
        'library': p.join(pair.theirs, 'lib$name.dylib'),
        'symbol': pair.symbol,
        'queries': pair.theirs,
        'files': pair.shared,
        'texts': [for (final input in pair.inputs) input.text],
      }),
    );
  return parseInProcesses(
    pair.inputs.length,
    (first, results) => Process.start(Platform.resolvedExecutable, [
      parser,
      request.path,
      '$first',
      results,
    ]),
    scratch: directory,
  );
}

/// Parses every input of [pair] with this archive's grammar under
/// [runtime], compares each tree and each capture of the query files both
/// archives carry with what [there] read of the other's, extracted at
/// [archive], prints each difference and each input the other's grammar
/// crashed on, and adds them to [totals].
///
/// The other's query files are compiled here as well, for the summary's
/// counts, and the comparison fails unless its processes compiled the
/// same files, since a capture is compared only for a file both sides
/// compiled.
void _compareGrammar(
  TreeSitterRuntime runtime,
  String archive,
  _Pair pair,
  ProcessParses there,
  _Totals totals,
) {
  final (:grammar, :theirs, :symbol, :onlyOurs, :onlyTheirs, :shared, :inputs) =
      pair;
  final ours = openLanguage(
    p.join(grammar.directory, 'lib${grammar.name}.dylib'),
    grammar.symbol,
  );
  final their = openLanguage(
    p.join(theirs, 'lib${grammar.name}.dylib'),
    symbol,
  );
  for (final file in onlyOurs) {
    print('${grammar.name}/$file: only in this archive');
  }
  for (final file in onlyTheirs) {
    print('${grammar.name}/$file: only in $archive');
  }
  final ourQueries = _compileAll(runtime, ours, grammar.directory, shared);
  final theirQueries = _compileAll(runtime, their, theirs, shared);
  final compiledHere = theirQueries.keys.join(', ');
  totals.addQueries(ourQueries, theirQueries);
  for (final query in theirQueries.values) {
    query.delete();
  }
  try {
    if (there.startProblem case final problem?) {
      stderr.writeln(
        '✗ ${grammar.name}: the old release\'s library parses nothing in a '
        'process of its own: $problem',
      );
      exitCode = 1;
      return;
    }
    final compiledThere = there.queries?.join(', ');
    if (inputs.isNotEmpty && compiledThere != compiledHere) {
      String named(String? files) =>
          files == null || files.isEmpty ? 'no query file' : files;
      stderr.writeln(
        '✗ ${grammar.name}: the old release\'s process compiles '
        '${named(compiledThere)}, where this process compiles '
        '${named(compiledHere)}',
      );
      exitCode = 1;
      return;
    }
    _compareInputs(runtime, grammar, ours, ourQueries, inputs, there, totals);
  } finally {
    for (final query in ourQueries.values) {
      query.delete();
    }
  }
}

/// Parses each of [inputs] with [ours], the language of [grammar], and
/// compares it with the parse of it [there] read, printing each
/// difference, each input the other's grammar crashed on and a line for
/// the grammar, and adding them to [totals].
void _compareInputs(
  TreeSitterRuntime runtime,
  _Grammar grammar,
  Pointer<Void> ours,
  Map<String, Query> ourQueries,
  List<_Input> inputs,
  ProcessParses there,
  _Totals totals,
) {
  final name = grammar.name;
  final crashedOn = {
    for (final (:index, :problem) in there.failures) index: problem,
  };
  var trees = 0;
  var captures = 0;
  for (final (index, input) in inputs.indexed) {
    final b = there.parsed[index];
    if (b == null) {
      print('$name: the old release crashes on ${input.label}');
      print('  ${crashedOn[index]}');
      continue;
    }
    final a = runtime.parse(ours, input.text, ourQueries);
    if (a.nodes != b.nodes) {
      trees++;
      print(
        '$name: tree differs '
        '(${a.tree == b.tree ? 'anonymous nodes only' : 'named nodes too'})'
        ': ${input.label}',
      );
      print('  ${_firstDifference(a.nodes, b.nodes)}');
    }
    for (final MapEntry(key: file, value: ourCaptures) in a.captures.entries) {
      final theirCaptures = b.captures[file];
      if (theirCaptures == null) continue;
      final difference = _captureDifference(
        ourCaptures,
        theirCaptures,
        input.text,
      );
      if (difference != null) {
        captures++;
        print('$name/$file differs: ${input.label}');
        print('  $difference');
      }
    }
  }
  print(
    inputs.isEmpty
        ? '$name: no corpus or highlight tests to parse'
        : '$name: ${inputs.length} inputs, $trees tree differences, '
              '$captures query-result differences'
              '${crashedOn.isEmpty ? '' : '; the old release crashes on '
                        '${crashedOn.length}'}',
  );
  totals.addGrammar(grammar, inputs.length, trees, captures, crashedOn.length);
}

/// What the comparison found across every grammar, for its summary.
final class _Totals {
  var _inputs = 0;
  final _treeDifferences = <String, int>{};
  final _queryDifferences = <String, int>{};
  final _crashes = <String, int>{};
  final _uncompared = <_Grammar>[];
  var _ourPatterns = 0;
  var _theirPatterns = 0;
  final _ourPredicates = _PredicateTally();
  final _theirPredicates = _PredicateTally();

  /// Adds the patterns of [ours] and [theirs], the compiled query files
  /// both archives carry of one grammar.
  void addQueries(Map<String, Query> ours, Map<String, Query> theirs) {
    _ourPatterns += ours.values.fold(0, (sum, q) => sum + q.patternCount);
    _theirPatterns += theirs.values.fold(0, (sum, q) => sum + q.patternCount);
    _ourPredicates.addAll(ours);
    _theirPredicates.addAll(theirs);
  }

  /// Adds what comparing [inputs] inputs of [grammar] found: [trees] tree
  /// differences, [captures] query-result differences and [crashes] inputs
  /// the other archive's grammar crashed on.
  void addGrammar(
    _Grammar grammar,
    int inputs,
    int trees,
    int captures,
    int crashes,
  ) {
    _inputs += inputs;
    if (inputs == 0) _uncompared.add(grammar);
    if (trees > 0) _treeDifferences[grammar.name] = trees;
    if (captures > 0) _queryDifferences[grammar.name] = captures;
    if (crashes > 0) _crashes[grammar.name] = crashes;
  }

  /// Prints the summary of the comparison with the archive extracted at
  /// [archive], and sets a failing exit code when that archive's manifest
  /// pins a grammar with no inputs at another commit.
  void report(String archive) {
    int sum(Map<String, int> counts) => counts.values.fold(0, (a, b) => a + b);
    print(
      '\n$_inputs inputs: ${sum(_treeDifferences)} tree differences '
      '${_treeDifferences.isEmpty ? '' : '$_treeDifferences '}and '
      '${sum(_queryDifferences)} query-result differences'
      '${_queryDifferences.isEmpty ? '' : ' $_queryDifferences'}; '
      'patterns in the query files both carry: $_ourPatterns here, '
      '$_theirPatterns there',
    );
    if (_crashes.isNotEmpty) {
      print(
        'inputs the old release crashes on, which are not compared: '
        '${sum(_crashes)} $_crashes',
      );
    }
    print(
      'predicates evaluated on each match: ${_ourPredicates.evaluated} '
      'here, ${_theirPredicates.evaluated} there; patterns whose captures '
      'carry their other predicates and directives as text: '
      '${_ourPredicates.carried} here, ${_theirPredicates.carried} there',
    );
    _reportUncompared(archive);
  }

  /// Lists every grammar with no inputs, failing when the manifest of the
  /// archive extracted at [archive] pins one of them at another commit.
  void _reportUncompared(String archive) {
    if (_uncompared.isEmpty) return;
    final manifest = File(p.join(archive, 'manifest.json'));
    final theirPins = <String, String>{
      if (manifest.existsSync())
        for (final MapEntry(:key, :value) in _json(manifest.path).entries)
          if (value case {'source': {'commit': final String commit}})
            key: commit,
    };
    print(
      'not compared, having no inputs: '
      '${_uncompared.map((g) => g.name).join(', ')}'
      '${theirPins.isEmpty ? '; $archive records no pins, so any of these '
                'may have changed unseen' : ''}',
    );
    final repinned = [
      for (final grammar in _uncompared)
        if (theirPins[grammar.name] case final pin? when pin != grammar.commit)
          grammar.name,
    ];
    if (repinned.isNotEmpty) {
      stderr.writeln(
        '✗ ${repinned.join(', ')}: pinned at another commit than in '
        '$archive, with no inputs to compare',
      );
      exitCode = 1;
    }
  }
}

/// The tree each grammar repository's tests are read from, by repository
/// name: its unpacked bundle under [sourceRoot], or, for a pin on a deploy
/// branch, the tree of its `sourceCommit`, which carries the tests a
/// deployed tree leaves out. That tree comes from `grammars/<repository>`
/// under [root], fetched as needed, and is extracted into [scratch]. A
/// repository whose tree cannot be supplied is printed and left out.
Future<Map<String, String>> _testTrees(
  String root,
  List<_Grammar> grammars,
  String sourceRoot,
  String scratch,
) async {
  final trees = <String, String>{};
  final seen = <String>{};
  for (final grammar in grammars) {
    final name = repositoryName(grammar.url);
    if (!seen.add(name)) continue;
    final sourceCommit = grammar.sourceCommit;
    if (sourceCommit == null) {
      trees[name] = p.join(sourceRoot, name);
      continue;
    }
    final destination = p.join(
      scratch,
      '$name@${sourceCommit.substring(0, 8)}',
    );
    try {
      final store = p.join(root, 'grammars', name);
      await ensureObjectStore(runGit, store, grammar.url);
      await ensureCommit(runGit, store, sourceCommit, name);
      Directory(scratch).createSync(recursive: true);
      await extractCommit(store, sourceCommit, destination);
      trees[name] = destination;
      print('$name: tests read at its source commit $sourceCommit');
    } on Exception catch (error) {
      print('$name: cannot read the tests at its source commit: $error');
    }
  }
  return trees;
}

/// What the compared queries' patterns hold, for the summary.
final class _PredicateTally {
  var evaluated = 0;
  var carried = 0;

  /// Adds every pattern of [queries], printing each regular expression
  /// Dart refused, which is compared as text instead.
  void addAll(Map<String, Query> queries) {
    for (final MapEntry(key: file, value: query) in queries.entries) {
      for (final pattern in query.predicates) {
        evaluated += pattern.evaluated;
        if (pattern.properties.isNotEmpty) carried++;
        for (final regex in pattern.refusedRegexes) {
          print('$file: Dart refuses ${jsonEncode(regex)}; compared as text');
        }
      }
    }
  }
}

Map<String, Query> _compileAll(
  TreeSitterRuntime runtime,
  Pointer<Void> language,
  String directory,
  List<String> files,
) {
  final queries = <String, Query>{};
  for (final file in files) {
    try {
      queries[file] = runtime.compile(language, composeQuery(directory, file)!);
    } on QueryInheritanceException catch (error) {
      print('$error, so it is not compared');
    } on QueryException catch (error) {
      print('${p.basename(directory)}/$file does not compile: $error');
    }
  }
  return queries;
}

/// Every corpus example and highlight input in [repository], the test tree
/// of [grammar]'s repository, that [grammar] parses: an example names its
/// language with `:language(...)` or falls to its corpus's default
/// grammar, and a highlight input goes to the grammar whose extensions
/// include its own.
List<_Input> _inputs(
  _Grammar grammar,
  List<_Grammar> grammars,
  String repository,
) {
  final labels = p.dirname(repository);
  final siblings = grammars.where((g) => g.url == grammar.url).toList();
  final firstName = _firstGrammarName(repository) ?? siblings.first.name;
  final inputs = <_Input>[];
  void readTests(String base, String defaultName) {
    final corpus = [
      Directory(p.join(repository, base, 'test', 'corpus')),
      Directory(p.join(repository, base, 'corpus')),
    ].where((directory) => directory.existsSync()).firstOrNull;
    for (final file in corpus == null ? const <File>[] : _files(corpus)) {
      final label = p.relative(file.path, from: labels);
      for (final example in parseCorpus(file.readAsStringSync())) {
        for (final language in example.languages) {
          final target = language.isEmpty ? defaultName : language;
          if (target == grammar.name) {
            inputs.add((label: '$label: ${example.name}', text: example.input));
          }
        }
      }
    }
    final highlight = Directory(p.join(repository, base, 'test', 'highlight'));
    for (final file in _files(highlight)) {
      final extension = p.extension(file.path);
      final owner = siblings
          .where((g) => g.extensions.contains(extension))
          .map((g) => g.name)
          .firstOrNull;
      if ((owner ?? defaultName) == grammar.name) {
        inputs.add((
          label: p.relative(file.path, from: labels),
          text: utf8.decode(file.readAsBytesSync(), allowMalformed: true),
        ));
      }
    }
  }

  if (grammar.path != '.' &&
      ['test', 'corpus'].any(
        (d) => Directory(p.join(repository, grammar.path, d)).existsSync(),
      )) {
    readTests(grammar.path, grammar.name);
  } else {
    readTests('.', firstName);
  }
  return inputs;
}

String? _firstGrammarName(String repository) {
  final file = File(p.join(repository, 'tree-sitter.json'));
  if (!file.existsSync()) return null;
  final grammars = (jsonDecode(file.readAsStringSync()) as Map)['grammars'];
  return grammars is List && grammars.isNotEmpty
      ? (grammars.first as Map)['name'] as String?
      : null;
}

/// Every file under [directory], sorted by path; none when it does not
/// exist.
List<File> _files(Directory directory) {
  if (!directory.existsSync()) return const [];
  return [
    for (final entity in directory.listSync(recursive: true))
      if (entity is File) entity,
  ]..sort((a, b) => a.path.compareTo(b.path));
}

/// The first line where the node listings [a] and [b] differ.
String _firstDifference(String a, String b) {
  final ours = a.split('\n');
  final theirs = b.split('\n');
  var index = 0;
  while (index < ours.length &&
      index < theirs.length &&
      ours[index] == theirs[index]) {
    index++;
  }
  String at(List<String> lines) =>
      index < lines.length ? lines[index].trim() : '(end)';
  return 'node ${index + 1}: here ${at(ours)}; there ${at(theirs)}';
}

/// The captures in only one of [ours] and [theirs], or null when they hold
/// the same captures the same number of times. A capture is its name, its
/// node's byte range and the unevaluated predicates and directives of the
/// pattern that made it, so a changed `#set!` is a difference too.
String? _captureDifference(
  List<Capture> ours,
  List<Capture> theirs,
  String text,
) {
  final counts = <Capture, int>{};
  for (final capture in ours) {
    counts[capture] = (counts[capture] ?? 0) + 1;
  }
  for (final capture in theirs) {
    counts[capture] = (counts[capture] ?? 0) - 1;
  }
  final onlyOurs = [
    for (final MapEntry(:key, :value) in counts.entries)
      if (value > 0) key,
  ];
  final onlyTheirs = [
    for (final MapEntry(:key, :value) in counts.entries)
      if (value < 0) key,
  ];
  if (onlyOurs.isEmpty && onlyTheirs.isEmpty) return null;
  final bytes = utf8.encode(text);
  String show(Capture capture) {
    final start = capture.start.clamp(0, bytes.length);
    final end = capture.end.clamp(start, bytes.length);
    final snippet = utf8.decode(
      bytes.sublist(start, end.clamp(start, start + 40)),
      allowMalformed: true,
    );
    final properties = capture.properties.isEmpty
        ? ''
        : ' ${capture.properties}';
    return '${capture.name}@${capture.start}-${capture.end}$properties '
        '${jsonEncode(snippet)}';
  }

  return [
    '${onlyOurs.length} captures only here, ${onlyTheirs.length} only there',
    if (onlyOurs.isNotEmpty) 'here: ${onlyOurs.take(3).map(show).join(', ')}',
    if (onlyTheirs.isNotEmpty)
      'there: ${onlyTheirs.take(3).map(show).join(', ')}',
  ].join('; ');
}
