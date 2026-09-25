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
/// - Every source bundle in `<output>/sources/` has the sha256
///   `build_info.json` records and names its pinned commit, and the
///   bundles are exactly the runtime and the grammars `tool/grammars.json`
///   pins.
/// - `libtree-sitter.dylib` exports every function the runtime's `api.h`
///   declares, apart from the three it defines only with its wasm feature.
/// - The runtime and every grammar library is a thin binary of the
///   toolchain's architecture with its `minos`, an `@rpath` install name
///   and no dependency beyond `libSystem`.
/// - `ts_parser_set_language` accepts every grammar, whose
///   `ts_language_abi_version` is 13 to 15, found through its
///   `config.json` `symbol`.
/// - Every query file of every grammar, composed with what its
///   `; inherits:` line names as the editor composes it, compiles with
///   `ts_query_new`.
/// - `THIRD_PARTY_NOTICES.md` is the committed text and names the runtime,
///   every source bundle's commit, every shipped query file and the
///   licences the archive has to carry.
///
/// `--against=<archive>` then compares the grammars of another extracted
/// archive with these, both under this runtime: every example of each
/// grammar's test corpus and every highlight test input from the pinned
/// sources is parsed with both, and each difference in the tree, or in
/// the captures of a query file both archives carry, is printed. It
/// reports and does not fail.
library;

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'src/grammar_pins.dart';
import 'src/macho.dart';
import 'src/notices.dart';
import 'src/release_check.dart';
import 'src/source_bundles.dart';
import 'src/toolchain.dart';
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
        grammars,
        p.normalize(p.absolute(against)),
        sources,
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
  List<String> problems,
) async {
  final toolchain = Toolchain.load(root);
  final info = _json(p.join(output, 'build_info.json'));
  final manifest = _json(p.join(output, 'manifest.json'));
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
  await _checkSources(root, output, toolchain, info, sourceRoot, problems);

  final runtimePath = p.join(output, 'libtree-sitter.dylib');
  final runtime = TreeSitterRuntime.open(runtimePath);
  _checkExports(runtime, p.join(sourceRoot, 'tree-sitter'), problems);

  final grammars = [
    for (final MapEntry(key: name, value: entry) in manifest.entries)
      if (entry case {
        'dylib_dir': final String directory,
        'source': {'url': final String url, 'path': final String path},
        'extensions': final List<Object?> extensions,
      })
        (
          name: name,
          directory: p.join(output, directory),
          symbol:
              _json(p.join(output, directory, 'config.json'))['symbol']
                  as String? ??
              '',
          url: url,
          path: path,
          extensions: extensions.cast<String>(),
        ),
  ];
  await _checkLibraries(runtimePath, grammars, toolchain, problems);
  final languages = _checkGrammars(runtime, grammars, problems);
  _checkQueries(runtime, grammars, languages, problems);
  _checkNotices(root, output, info, problems);
  return (runtime: runtime, grammars: grammars, sources: sourceRoot);
}

/// Checks every bundle against `build_info.json` and the pins, and unpacks
/// each into [sourceRoot].
Future<void> _checkSources(
  String root,
  String output,
  Toolchain toolchain,
  Map<String, Object?> info,
  String sourceRoot,
  List<String> problems,
) async {
  final recorded = info['sources'];
  if (recorded is! Map<String, Object?>) {
    problems.add('build_info.json records no sources');
    return;
  }
  final pinned = pinnedSources(
    toolchain,
    parseGrammars(
      File(p.join(root, 'tool', 'grammars.json')).readAsStringSync(),
    ),
  );
  final bundles = p.join(output, sourcesDirectoryName);
  var good = 0;
  for (final source in pinned) {
    try {
      await checkRecordedBundle(bundles, source, recorded);
      await unpackBundle(
        p.join(bundles, source.bundleName),
        p.join(sourceRoot, source.name),
      );
      good++;
    } on SourceBundleException catch (error) {
      problems.add('$error');
    }
  }
  final extra = recorded.keys.toSet().difference({
    for (final source in pinned) source.name,
  });
  if (extra.isNotEmpty) {
    problems.add('build_info.json records unpinned sources $extra');
  }
  final files = Directory(bundles).existsSync()
      ? Directory(bundles).listSync().length
      : 0;
  if (files != pinned.length) {
    problems.add('$bundles holds $files files for ${pinned.length} pins');
  }
  print(
    'sources: $good/${pinned.length} bundles carry their recorded sha256 '
    'and pinned commit',
  );
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

/// Opens every grammar and returns its language by name.
Map<String, Pointer<Void>> _checkGrammars(
  TreeSitterRuntime runtime,
  List<_Grammar> grammars,
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
    if (abi < 13 || abi > 15) {
      problems.add('${grammar.name}: language ABI $abi is outside 13..15');
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

/// The query files of a grammar's directory, sorted.
List<String> _queryFiles(String directory) => [
  for (final entity in Directory(directory).listSync())
    if (entity is File && entity.path.endsWith('.scm')) p.basename(entity.path),
]..sort();

void _checkQueries(
  TreeSitterRuntime runtime,
  List<_Grammar> grammars,
  Map<String, Pointer<Void>> languages,
  List<String> problems,
) {
  var files = 0;
  var compiled = 0;
  var patterns = 0;
  for (final grammar in grammars) {
    final language = languages[grammar.name];
    for (final file in _queryFiles(grammar.directory)) {
      files++;
      final source = composeQuery(grammar.directory, file)!;
      if (language == null) continue;
      try {
        final query = runtime.compile(language, source);
        patterns += query.patternCount;
        query.delete();
        compiled++;
      } on QueryException catch (error) {
        problems.add(
          '${grammar.name}/$file: $error (composed line '
          '${_lineAt(source, error.byteOffset)})',
        );
      }
    }
  }
  print('queries: $compiled/$files composed files compile, $patterns patterns');
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

/// Compares [grammars] with the same grammars in the archive extracted at
/// [archive], parsing the inputs of the sources unpacked under
/// [sourceRoot].
Future<void> _compare(
  TreeSitterRuntime runtime,
  List<_Grammar> grammars,
  String archive,
  String sourceRoot,
) async {
  print('\n── Comparing with $archive under this runtime');
  var totalInputs = 0;
  final treeDifferences = <String, int>{};
  final queryDifferences = <String, int>{};
  var ourPatterns = 0;
  var theirPatterns = 0;
  for (final grammar in grammars) {
    final theirs = p.join(archive, 'dylibs', grammar.name);
    final theirLibrary = p.join(theirs, 'lib${grammar.name}.dylib');
    if (!File(theirLibrary).existsSync()) {
      print('${grammar.name}: not in $archive');
      continue;
    }
    final ours = openLanguage(
      p.join(grammar.directory, 'lib${grammar.name}.dylib'),
      grammar.symbol,
    );
    final symbol =
        _json(p.join(theirs, 'config.json'))['symbol'] as String? ??
        grammar.symbol;
    final their = openLanguage(theirLibrary, symbol);
    final ourFiles = _queryFiles(grammar.directory).toSet();
    final theirFiles = _queryFiles(theirs).toSet();
    for (final file in ourFiles.difference(theirFiles)) {
      print('${grammar.name}/$file: only in this archive');
    }
    for (final file in theirFiles.difference(ourFiles)) {
      print('${grammar.name}/$file: only in $archive');
    }
    final shared = ourFiles.intersection(theirFiles).toList()..sort();
    final ourQueries = _compileAll(runtime, ours, grammar.directory, shared);
    final theirQueries = _compileAll(runtime, their, theirs, shared);
    ourPatterns += ourQueries.values.fold(0, (sum, q) => sum + q.patternCount);
    theirPatterns += theirQueries.values.fold(
      0,
      (sum, q) => sum + q.patternCount,
    );
    final inputs = _inputs(grammar, grammars, sourceRoot);
    totalInputs += inputs.length;
    var trees = 0;
    var captures = 0;
    for (final input in inputs) {
      final a = runtime.parse(ours, input.text, ourQueries);
      final b = runtime.parse(their, input.text, theirQueries);
      if (a.nodes != b.nodes) {
        trees++;
        print(
          '${grammar.name}: tree differs '
          '(${a.tree == b.tree ? 'anonymous nodes only' : 'named nodes too'})'
          ': ${input.label}',
        );
        print('  ${_firstDifference(a.nodes, b.nodes)}');
      }
      for (final name in shared) {
        final ourCaptures = a.captures[name];
        final theirCaptures = b.captures[name];
        if (ourCaptures == null || theirCaptures == null) continue;
        final difference = _captureDifference(
          ourCaptures,
          theirCaptures,
          input.text,
        );
        if (difference != null) {
          captures++;
          print('${grammar.name}/$name differs: ${input.label}');
          print('  $difference');
        }
      }
    }
    for (final query in [...ourQueries.values, ...theirQueries.values]) {
      query.delete();
    }
    if (trees > 0) treeDifferences[grammar.name] = trees;
    if (captures > 0) queryDifferences[grammar.name] = captures;
    print(
      inputs.isEmpty
          ? '${grammar.name}: no corpus or highlight tests at its pin'
          : '${grammar.name}: ${inputs.length} inputs, $trees tree '
                'differences, $captures query-result differences',
    );
  }
  print(
    '\n$totalInputs inputs: '
    '${treeDifferences.values.fold(0, (a, b) => a + b)} tree differences '
    '${treeDifferences.isEmpty ? '' : '$treeDifferences '}and '
    '${queryDifferences.values.fold(0, (a, b) => a + b)} query-result '
    'differences${queryDifferences.isEmpty ? '' : ' $queryDifferences'}; '
    'patterns in the query files both carry: $ourPatterns here, '
    '$theirPatterns there',
  );
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
    } on QueryException catch (error) {
      print('${p.basename(directory)}/$file does not compile: $error');
    }
  }
  return queries;
}

/// Every corpus example and highlight input of [grammar]'s repository that
/// [grammar] parses: an example names its language with `:language(...)`
/// or falls to its corpus's default grammar, and a highlight input goes to
/// the grammar whose extensions include its own.
List<_Input> _inputs(
  _Grammar grammar,
  List<_Grammar> grammars,
  String sourceRoot,
) {
  final repository = p.join(sourceRoot, repositoryName(grammar.url));
  final siblings = grammars.where((g) => g.url == grammar.url).toList();
  final firstName = _firstGrammarName(repository) ?? siblings.first.name;
  final inputs = <_Input>[];
  void readTests(String base, String defaultName) {
    final corpus = [
      Directory(p.join(repository, base, 'test', 'corpus')),
      Directory(p.join(repository, base, 'corpus')),
    ].where((directory) => directory.existsSync()).firstOrNull;
    for (final file in corpus == null ? const <File>[] : _files(corpus)) {
      final label = p.relative(file.path, from: sourceRoot);
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
          label: p.relative(file.path, from: sourceRoot),
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
/// the same captures the same number of times.
String? _captureDifference(
  List<Capture> ours,
  List<Capture> theirs,
  String text,
) {
  String key(Capture capture) =>
      '${capture.name}@${capture.start}-${capture.end}';
  final counts = <String, int>{};
  for (final capture in ours) {
    counts[key(capture)] = (counts[key(capture)] ?? 0) + 1;
  }
  for (final capture in theirs) {
    counts[key(capture)] = (counts[key(capture)] ?? 0) - 1;
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
  String show(String capture) {
    final range = capture.substring(capture.lastIndexOf('@') + 1).split('-');
    final start = int.parse(range[0]).clamp(0, bytes.length);
    final end = int.parse(range[1]).clamp(start, bytes.length);
    final snippet = utf8.decode(
      bytes.sublist(start, end.clamp(start, start + 40)),
      allowMalformed: true,
    );
    return '$capture ${jsonEncode(snippet)}';
  }

  return [
    '${onlyOurs.length} captures only here, ${onlyTheirs.length} only there',
    if (onlyOurs.isNotEmpty) 'here: ${onlyOurs.take(3).map(show).join(', ')}',
    if (onlyTheirs.isNotEmpty)
      'there: ${onlyTheirs.take(3).map(show).join(', ')}',
  ].join('; ');
}
