/// Generates `THIRD_PARTY_NOTICES.md`: every licence the grammars archive
/// carries, copied verbatim, so the file stands alone wherever the archive
/// goes.
///
/// It reproduces the tree-sitter runtime's licences, each pinned grammar's
/// licence and NOTICE files, every licence comment the runtime's or a
/// grammar's compiled sources carry beyond those, the Apache License 2.0 of
/// the query files derived from nvim-treesitter, and this repository's own
/// licence, and it lists where every query file came from and every patch
/// applied to a grammar's sources.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'git.dart';
import 'grammar_pins.dart';
import 'grammar_plan.dart';
import 'query_headers.dart';
import 'query_provenance.dart';
import 'source_patches.dart';
import 'toolchain.dart';

/// The generated file's name, at the repository root and in the archive.
const noticesFileName = 'THIRD_PARTY_NOTICES.md';

/// The runtime's licence files, relative to its repository root.
const runtimeLicenseFiles = ['LICENSE', 'lib/src/unicode/LICENSE'];

/// The runtime's include directories, relative to its repository root, in
/// the order its one compile searches them.
const runtimeIncludeDirectories = ['lib/src', 'lib/src/wasm', 'lib/include'];

/// Matches a licence file's name at a repository's root.
final licenseFilePattern = RegExp(
  r'^(licen[cs]e|copying)(\.(md|txt))?$',
  caseSensitive: false,
);

/// Matches a NOTICE file's name at a repository's root, which is
/// reproduced beside its licence.
final noticeFilePattern = RegExp(
  r'^notice(\.(md|txt))?$',
  caseSensitive: false,
);

/// What marks a comment as a licence statement: a copyright, a licence, an
/// SPDX identifier, a public-domain dedication, a permission grant, a
/// reservation of rights, a copyright sign or `(c)`.
final _licenseMark = RegExp(
  r'copyright|licen[cs]e|spdx-license-identifier|public\s+domain|'
  r'permission\s+is\s+hereby\s+granted|all\s+rights\s+reserved|\u00a9|'
  r'\(c\)',
  caseSensitive: false,
);

/// [_licenseMark] without `(c)`, which C code writes wherever it passes a
/// variable named `c`, so it can be counted outside comments too.
final _licenseWord = RegExp(
  r'copyright|licen[cs]e|spdx-license-identifier|public\s+domain|'
  r'permission\s+is\s+hereby\s+granted|all\s+rights\s+reserved|\u00a9',
  caseSensitive: false,
);

/// Thrown when the notices cannot be generated, listing every reason.
final class NoticesException implements Exception {
  const NoticesException(this.problems);

  final List<String> problems;

  @override
  String toString() => ['notices:', ...problems].join('\n  ');
}

/// Everything [thirdPartyNotices] reads.
final class NoticesInput {
  const NoticesInput({
    required this.toolchain,
    required this.runtimeDirectory,
    required this.entries,
    required this.builds,
    required this.sourceRoot,
    required this.provenance,
    required this.apacheLicense,
    required this.ownLicense,
    required this.patchRoot,
  });

  final Toolchain toolchain;

  /// The runtime's extracted tree at [Toolchain.treeSitterCommit].
  final String runtimeDirectory;

  /// `tool/grammars.json`.
  final List<Map<String, Object?>> entries;

  /// The grammars the build compiles.
  final List<GrammarBuild> builds;

  /// The directory holding each grammar repository's extracted tree, by
  /// repository name: the repository root's `build/src` for [builds].
  final String sourceRoot;

  /// `tool/query_provenance.json`, read and checked against every query
  /// file.
  final ProvenanceReading provenance;

  /// `LICENSES/Apache-2.0.txt`.
  final String apacheLicense;

  /// This repository's `LICENSE`.
  final String ownLicense;

  /// The directory the `patches` of [entries] are paths under: this
  /// repository's root, or the tree of the commit a release builds.
  final String patchRoot;
}

/// The contents of `THIRD_PARTY_NOTICES.md`.
///
/// Throws a [NoticesException] listing every problem: a grammar with no
/// `license` field or no licence file at its root, a licence or NOTICE
/// file that is not UTF-8 text, a query file the provenance does not list,
/// and every compiled source problem [_sourceNotices] finds, for the runtime
/// against `toolchain.json`'s `treeSitter.extraNotices` and for a grammar
/// against its entry's `extraNotices`.
String thirdPartyNotices(NoticesInput input) {
  final problems = [...input.provenance.problems];
  final runtimeLicenses = _readLicenses(
    input.runtimeDirectory,
    [
      ...runtimeLicenseFiles,
      ..._rootFiles(input.runtimeDirectory, noticeFilePattern),
    ],
    'tree-sitter',
    problems,
  );
  final runtimeNotices = _sourceNotices(
    directory: input.runtimeDirectory,
    sources: [
      for (final source in includedFiles(input.runtimeDirectory, [
        'lib/src/lib.c',
      ], runtimeIncludeDirectories))
        if (!source.startsWith('lib/src/unicode/')) source,
    ],
    extraNotices: input.toolchain.runtimeExtraNotices,
    name: 'tree-sitter',
    listedIn: "toolchain.json's treeSitter.extraNotices",
    problems: problems,
  );
  final grammars = [
    for (final entry in input.entries)
      if (entry['url'] is String) _grammarNotice(input, entry, problems),
  ];
  final licenseOf = licenseLookup(input.entries);
  String? queries;
  try {
    queries = _querySection(input.provenance.entries, licenseOf);
  } on QueryHeaderException catch (error) {
    problems.add('$error');
  }
  if (problems.isNotEmpty) throw NoticesException(problems);
  final buffer = StringBuffer()
    ..write(_introduction(input))
    ..write(
      _runtimeSection(
        input.toolchain,
        runtimeLicenses,
        _extraNoticeBlocks(
          runtimeNotices,
          input.toolchain.runtimeExtraNotices,
          'the runtime',
          level: 3,
        ),
      ),
    )
    ..write('## Grammars\n\n')
    ..write(
      'Each grammar library is compiled from its repository at the commit '
      'named, and that repository\'s licence covers it.\n\n',
    );
  for (final grammar in grammars) {
    buffer.write(grammar);
  }
  buffer
    ..write(queries)
    ..write('## tree-sitter-grammars\n\n')
    ..write(
      'The query files written in tree-sitter-grammars, the changes it '
      'made to the others, and the patches it applies to the sources of '
      'the grammars named under "Grammars" are covered by its own '
      'licence.\n\n',
    )
    ..write(_fenced('LICENSE', input.ownLicense))
    ..write('## Apache License 2.0\n\n')
    ..write(
      'The licence of nvim-treesitter, from which the query files listed '
      'under "Derived from nvim-treesitter" come.\n\n',
    )
    ..write(_fenced(null, input.apacheLicense));
  return buffer.toString();
}

String _introduction(NoticesInput input) {
  final tag = input.toolchain.treeSitterTag;
  return '# Third-party notices\n\n'
      'The grammars archive of '
      'https://github.com/tkinnis/tree-sitter-grammars carries the '
      'tree-sitter runtime ($tag), one library per grammar and the query '
      'files each language reads. This file reproduces, verbatim, the '
      'licence of every one of them.\n\n'
      'In the archive, `libtree-sitter.dylib` is the runtime, '
      '`dylibs/<language>/` holds a grammar\'s library beside its query '
      'files, and `queries/<language>/` holds the query files of a '
      'language that has no library of its own. The query files are this '
      'repository\'s `queries/<language>/*.scm`.\n\n';
}

String _runtimeSection(
  Toolchain toolchain,
  List<(String, String)> licenses,
  String extraNotices,
) {
  final buffer = StringBuffer()
    ..write('## tree-sitter\n\n')
    ..write(
      '`libtree-sitter.dylib` is compiled from '
      'https://github.com/tree-sitter/tree-sitter at '
      '${toolchain.treeSitterTag} '
      '(${toolchain.treeSitterCommit}). `lib/src/unicode/LICENSE` covers '
      'the ICU headers under `lib/src/unicode/` that it compiles in.\n\n',
    );
  for (final (path, text) in licenses) {
    buffer.write(_fenced(path, text));
  }
  return (buffer..write(extraNotices)).toString();
}

/// The licence and NOTICE files the notices reproduce of the repository
/// tree extracted at [directory], each name mapped to its bytes.
Map<String, List<int>> reproducedLicenseFiles(String directory) => {
  for (final name in [
    ..._rootFiles(directory, licenseFilePattern),
    ..._rootFiles(directory, noticeFilePattern),
  ])
    name: File(p.join(directory, name)).readAsBytesSync(),
};

/// The licence and NOTICE files at the root of [commit] in the git object
/// store [store], each name mapped to its committed bytes.
Future<Map<String, List<int>>> committedLicenseFiles(
  String store,
  String commit,
) async {
  final listing = await runIsolatedGit(store, ['ls-tree', '-z', commit]);
  final files = <String, List<int>>{};
  for (final record in listing.split('\x00').where((r) => r.isNotEmpty)) {
    final tab = record.indexOf('\t');
    final [_, type, object] = record.substring(0, tab).split(' ');
    final name = record.substring(tab + 1);
    if (type != 'blob' ||
        !(licenseFilePattern.hasMatch(name) ||
            noticeFilePattern.hasMatch(name))) {
      continue;
    }
    files[name] = await runIsolatedGitBytes(store, [
      'cat-file',
      'blob',
      object,
    ]);
  }
  return files;
}

/// Every citation in [provenance] of an upstream file whose commit is not
/// covered by the licence the notices reproduce for its repository.
///
/// [reproduced] maps each repository URL, as [normalizeRepositoryUrl]
/// writes it, to the licence and NOTICE files the notices reproduce for it:
/// for a grammar, those at its pin; for nvim-treesitter, the Apache License
/// 2.0 as its `LICENSE`. [filesAt] answers the licence and NOTICE files at
/// a cited commit, as [committedLicenseFiles] reads them; each repository
/// and commit is read once.
///
/// A citation is a problem when its repository is not in [reproduced],
/// when its commit has no licence file at its root, or when a licence or
/// NOTICE file there is not byte for byte the file of that name the notices
/// reproduce. A file cited at such a commit is attributed to a licence it
/// was never published under.
Future<List<String>> citedLicenseProblems(
  Map<String, QueryProvenance> provenance,
  Map<String, Map<String, List<int>>> reproduced,
  Future<Map<String, List<int>>> Function(UpstreamFile cited) filesAt,
) async {
  final read = <String, Map<String, List<int>>>{};
  final problems = <String>[];
  for (final file in provenance.keys.toList()..sort()) {
    final entry = provenance[file]!;
    for (final cited in [entry.upstream, entry.nvimUpstream].nonNulls) {
      final repository = normalizeRepositoryUrl(cited.repo);
      final expected = reproduced[repository];
      final at = '$repository @ ${cited.commit}';
      if (expected == null) {
        problems.add('$file: cites $at, whose licence the notices lack');
        continue;
      }
      final files = read['$repository@${cited.commit}'] ??= await filesAt(
        cited,
      );
      if (!files.keys.any(licenseFilePattern.hasMatch)) {
        problems.add('$file: cites $at, which has no licence file');
      }
      for (final MapEntry(key: name, value: bytes) in files.entries) {
        if (!_sameBytes(expected[name], bytes)) {
          problems.add(
            '$file: cites $at, whose $name is not the one the notices '
            'reproduce',
          );
        }
      }
    }
  }
  return problems;
}

bool _sameBytes(List<int>? a, List<int> b) {
  if (a == null || a.length != b.length) return false;
  for (var index = 0; index < a.length; index++) {
    if (a[index] != b[index]) return false;
  }
  return true;
}

/// The files at [directory]'s root whose names [pattern] matches, sorted;
/// none when [directory] does not exist.
List<String> _rootFiles(String directory, RegExp pattern) =>
    Directory(directory).existsSync()
    ? ([
        for (final entity in Directory(directory).listSync())
          if (entity is File && pattern.hasMatch(p.basename(entity.path)))
            p.basename(entity.path),
      ]..sort())
    : const [];

/// Reads [paths] under [directory], recording a problem for each that is
/// missing or not UTF-8.
List<(String, String)> _readLicenses(
  String directory,
  List<String> paths,
  String name,
  List<String> problems,
) {
  return [
    for (final path in paths)
      if (_readText(directory, path, name, problems) case final text?)
        (path, text),
  ];
}

/// The text of [path] under [directory], or null after recording in
/// [problems], under [name], that it is missing or not UTF-8: a notice
/// is reproduced verbatim or not at all.
String? _readText(
  String directory,
  String path,
  String name,
  List<String> problems,
) {
  final file = File(p.join(directory, path));
  if (!file.existsSync()) {
    problems.add('$name: no $path');
    return null;
  }
  try {
    return utf8.decode(file.readAsBytesSync());
  } on FormatException {
    problems.add('$name: $path is not UTF-8 text');
    return null;
  }
}

String _grammarNotice(
  NoticesInput input,
  Map<String, Object?> entry,
  List<String> problems,
) {
  final url = entry['url']! as String;
  final repository = repositoryName(url);
  final directory = p.join(input.sourceRoot, repository);
  final license = entry['license'];
  if (license is! String || license.isEmpty) {
    problems.add('$repository: grammars.json names no license');
  }
  final licenseFiles = _rootFiles(directory, licenseFilePattern);
  if (licenseFiles.isEmpty) {
    problems.add('$repository: no licence file at its root');
  }
  final licenses = _readLicenses(
    directory,
    [...licenseFiles, ..._rootFiles(directory, noticeFilePattern)],
    repository,
    problems,
  );
  final builds = input.builds.where((build) => build.entry == entry).toList();
  final extraNotices = [...?(entry['extraNotices'] as List?)?.cast<String>()];
  final noticed = _sourceNotices(
    directory: directory,
    sources: {
      for (final build in builds)
        ...compiledSources(
          directory,
          p.posix.normalize(p.posix.join(build.path, 'src')),
        ),
    }.toList(),
    extraNotices: extraNotices,
    name: repository,
    listedIn: "the entry's extraNotices",
    problems: problems,
  );
  final deployedFrom = switch (entry['sourceCommit']) {
    final String source => ', deployed from $source',
    _ => '',
  };
  final buffer = StringBuffer()
    ..write('### $repository\n\n')
    ..write(
      '${_libraryList(builds)} from $url at ${entry['commit']}'
      '$deployedFrom. Licence: $license.\n\n',
    )
    ..write(_patchList(input.patchRoot, entry, repository, problems));
  for (final (file, text) in licenses) {
    buffer.write(_fenced(file, text, level: 4));
  }
  return (buffer..write(
        _extraNoticeBlocks(noticed, extraNotices, 'the library', level: 4),
      ))
      .toString();
}

/// The paragraph naming each patch [entry] lists, read from under
/// [patchRoot], with the files it modifies; empty for an entry with none.
/// Records in [problems], under [repository], a patch that cannot be read.
String _patchList(
  String patchRoot,
  Map<String, Object?> entry,
  String repository,
  List<String> problems,
) {
  final patches = entryPatches(entry);
  if (patches.isEmpty) return '';
  final lines = <String>[];
  for (final patch in patches) {
    final file = File(p.join(patchRoot, patch));
    if (!file.existsSync()) {
      problems.add('$repository: no $patch');
      continue;
    }
    final paths = [
      for (final path in patchedPaths(file.readAsStringSync())) '`$path`',
    ];
    lines.add('- `$patch`, modifying ${paths.join(', ')}');
  }
  final one = patches.length == 1;
  return 'tree-sitter-grammars applies '
      '${one ? 'this patch' : 'these patches, in order,'} to the tree before '
      'compiling it. The files ${one ? 'it modifies' : 'they modify'} stay '
      'under the grammar\'s licence, and the changes are also covered by the '
      'licence of tree-sitter-grammars.\n\n'
      '${lines.join('\n')}\n\n';
}

/// The licence comments of every one of [sources], relative to
/// [directory], that carries any, by source.
///
/// Records in [problems], under [name]: a source that names a licence
/// outside its comments, which only a reader can reproduce, found as more
/// licence words in its raw text than in its comments; a source with a
/// licence comment that [extraNotices] does not name; and an entry of
/// [extraNotices] naming no such source. [listedIn] says where
/// [extraNotices] is written. The check errs toward stopping.
Map<String, List<String>> _sourceNotices({
  required String directory,
  required List<String> sources,
  required List<String> extraNotices,
  required String name,
  required String listedIn,
  required List<String> problems,
}) {
  final noticed = <String, List<String>>{};
  for (final source in sources) {
    final text = File(p.join(directory, source)).readAsStringSync();
    if (!_licenseMark.hasMatch(text)) continue;
    final comments = licenseComments(text);
    final commented = comments.fold(
      0,
      (count, comment) => count + _licenseWord.allMatches(comment).length,
    );
    if (_licenseWord.allMatches(text).length > commented) {
      problems.add(
        '$name: $source mentions a licence outside any comment, which the '
        'notices cannot reproduce; read it by hand',
      );
    }
    if (comments.isNotEmpty) noticed[source] = comments;
  }
  for (final source in noticed.keys) {
    if (!extraNotices.contains(source)) {
      problems.add(
        '$name: $source carries a licence comment; name it in $listedIn',
      );
    }
  }
  for (final source in extraNotices) {
    if (!noticed.containsKey(source)) {
      problems.add(
        '$name: $listedIn names $source, which is not compiled or carries '
        'no licence comment',
      );
    }
  }
  return noticed;
}

/// The licence comments [noticed] holds of each of [extraNotices], each
/// under a heading of [level] naming its file, which [compiledBy]
/// compiles in.
String _extraNoticeBlocks(
  Map<String, List<String>> noticed,
  List<String> extraNotices,
  String compiledBy, {
  required int level,
}) {
  final buffer = StringBuffer();
  for (final source in extraNotices) {
    final comments = noticed[source];
    if (comments == null) continue;
    buffer
      ..write(
        '${'#' * level} $source\n\n'
        'The licence comment${comments.length == 1 ? '' : 's'} of '
        '`$source`, which $compiledBy compiles in:\n\n',
      )
      ..write([for (final comment in comments) _fenced(null, comment)].join());
  }
  return buffer.toString();
}

String _libraryList(List<GrammarBuild> builds) {
  final names = [for (final build in builds) '`${build.dylibFileName}`'];
  final list = switch (names) {
    [] => 'No library',
    [final one] => one,
    [...final rest, final last] => '${rest.join(', ')} and $last',
  };
  return '$list ${names.length == 1 ? 'is' : 'are'} compiled';
}

/// The files a grammar's library compiles, relative to its repository
/// root [repositoryDirectory]: its `parser.c` and `scanner.c` in
/// [sourceDirectory] (relative to the repository root), and every file
/// they include, found as the compiler finds it, apart from the headers in
/// `src/tree_sitter/`, which are tree-sitter's.
List<String> compiledSources(
  String repositoryDirectory,
  String sourceDirectory,
) {
  final units = [
    for (final unit in const ['parser.c', 'scanner.c'])
      if (File(p.join(repositoryDirectory, sourceDirectory, unit)).existsSync())
        p.posix.normalize(p.posix.join(sourceDirectory, unit)),
  ];
  final headers = p.posix.normalize(
    p.posix.join(sourceDirectory, 'tree_sitter'),
  );
  return [
    for (final file in includedFiles(repositoryDirectory, units, [
      sourceDirectory,
    ]))
      if (!p.posix.isWithin(headers, file)) file,
  ];
}

final _include = RegExp(
  r'^\s*#\s*include\s*([<"])([^>"]+)[>"]',
  multiLine: true,
);

/// [units] and every file they include, directly or not, relative to
/// [root]; sorted.
///
/// A quoted include is looked up beside the file that names it and then in
/// [includeDirectories]; an angle-bracket include only in
/// [includeDirectories]. An include found nowhere under [root] is a system
/// header and is left out. Every `#include` counts, whatever conditional
/// surrounds it, so the result holds everything the compiler could read.
List<String> includedFiles(
  String root,
  List<String> units,
  List<String> includeDirectories,
) {
  final found = <String>{};
  final pending = [...units];
  while (pending.isNotEmpty) {
    final file = pending.removeLast();
    if (!found.add(file)) continue;
    final text = File(p.join(root, file)).readAsStringSync();
    for (final match in _include.allMatches(text)) {
      final name = match.group(2)!;
      final candidates = [
        if (match.group(1) == '"') p.posix.join(p.posix.dirname(file), name),
        for (final directory in includeDirectories)
          p.posix.join(directory, name),
      ];
      for (final candidate in candidates) {
        final normalized = p.posix.normalize(candidate);
        if (normalized.startsWith('../')) continue;
        if (File(p.join(root, normalized)).existsSync()) {
          pending.add(normalized);
          break;
        }
      }
    }
  }
  return found.toList()..sort();
}

/// Every comment in the C source [text] that makes a licence statement, in
/// full, in order. String and character literals are skipped, and a run of
/// line comments on consecutive lines is one comment.
List<String> licenseComments(String text) {
  final comments = <String>[];
  var index = 0;
  while (index < text.length) {
    final char = text[index];
    if (char == '"' || char == "'") {
      index++;
      while (index < text.length && text[index] != char) {
        index += text[index] == '\\' ? 2 : 1;
      }
      index++;
    } else if (text.startsWith('/*', index)) {
      final end = text.indexOf('*/', index + 2);
      final stop = end < 0 ? text.length : end + 2;
      comments.add(text.substring(index, stop));
      index = stop;
    } else if (text.startsWith('//', index)) {
      var stop = _lineEnd(text, index);
      while (stop < text.length) {
        var next = stop + 1;
        while (next < text.length &&
            (text[next] == ' ' || text[next] == '\t')) {
          next++;
        }
        if (!text.startsWith('//', next)) break;
        stop = _lineEnd(text, next);
      }
      comments.add(text.substring(index, stop));
      index = stop;
    } else {
      index++;
    }
  }
  return [
    for (final comment in comments)
      if (_licenseMark.hasMatch(comment)) comment,
  ];
}

/// The index of the newline ending the line [start] is on, or the end of
/// [text].
int _lineEnd(String text, int start) {
  final end = text.indexOf('\n', start);
  return end < 0 ? text.length : end;
}

String _querySection(
  Map<String, QueryProvenance> provenance,
  String Function(String) licenseOf,
) {
  final files = provenance.keys.toList()..sort();
  String name(String file) => file.substring('queries/'.length);
  String state(bool changed) =>
      changed ? 'modified in tree-sitter-grammars' : 'unchanged';
  String nvimState(QueryProvenance entry) =>
      entry.upstream!.repo == nvimTreesitterUrl
      ? state(entry.changed)
      : 'by way of the grammar\'s file below';
  final nvim = [
    for (final file in files)
      if (nvimSource(file, provenance[file]!) case final source?)
        '| `${name(file)}` | `${source.path}` | `${source.commit}` | '
            '${nvimState(provenance[file]!)} |',
  ];
  final grammar = [
    for (final file in files)
      if (provenance[file]!.upstream case final upstream?
          when upstream.repo != nvimTreesitterUrl)
        '| `${name(file)}` | ${repositoryName(upstream.repo)} | '
            '`${upstream.path}` | `${upstream.commit}` | '
            '${licenseOf(upstream.repo)} | '
            '${state(provenance[file]!.changed)} |',
  ];
  final here = [
    for (final file in files)
      if (provenance[file]!.origin == QueryOrigin.here) '- `${name(file)}`',
  ];
  return '## Query files\n\n'
      'Every query file came from one of three places: nvim-treesitter, a '
      'grammar\'s own repository, or tree-sitter-grammars itself. A file '
      'can carry lines from both of the first two.\n\n'
      '### Derived from nvim-treesitter\n\n'
      'These files are derived from $nvimTreesitterUrl, under the Apache '
      'License 2.0 reproduced below, which is nvim-treesitter\'s `LICENSE` '
      'at every commit named. Each one names, in a header at its top, the '
      'nvim-treesitter file and commit it derives from and whether '
      'tree-sitter-grammars modified it.\n\n'
      '| File | nvim-treesitter file | Commit | State |\n'
      '| --- | --- | --- | --- |\n'
      '${nvim.join('\n')}\n\n'
      '### From a grammar\'s repository\n\n'
      'These files come from the repository of a grammar listed under '
      '"Grammars" above, under the licence reproduced there: the licence '
      'and NOTICE files at every commit named are the ones reproduced '
      'there.\n\n'
      '| File | Repository | Path | Commit | Licence | State |\n'
      '| --- | --- | --- | --- | --- | --- |\n'
      '${grammar.join('\n')}\n\n'
      '### Written in tree-sitter-grammars\n\n'
      'These files are covered by the licence of tree-sitter-grammars, '
      'reproduced below.\n\n'
      '${here.join('\n')}\n\n';
}

/// [text] in a fenced block no line of [text] can close, under a heading
/// naming [title] when there is one.
String _fenced(String? title, String text, {int level = 3}) {
  var longest = 0;
  for (final match in RegExp('`+').allMatches(text)) {
    if (match.group(0)!.length > longest) longest = match.group(0)!.length;
  }
  final fence = '`' * (longest < 3 ? 3 : longest + 1);
  final body = text.endsWith('\n') ? text : '$text\n';
  return '${title == null ? '' : '${'#' * level} $title\n\n'}'
      '${fence}text\n$body$fence\n\n';
}
