/// Generates `THIRD_PARTY_NOTICES.md`: every licence the grammars archive
/// carries, copied verbatim, so the file stands alone wherever the archive
/// goes.
///
/// It reproduces the tree-sitter runtime's licences, each pinned grammar's
/// licence file, every copyright comment a grammar's compiled sources carry
/// beyond that licence, the Apache License 2.0 of the query files derived
/// from nvim-treesitter, and this repository's own licence, and it lists
/// where every query file came from.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'grammar_pins.dart';
import 'grammar_plan.dart';
import 'query_headers.dart';
import 'query_provenance.dart';
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

final _copyright = RegExp('copyright', caseSensitive: false);

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
}

/// The contents of `THIRD_PARTY_NOTICES.md`.
///
/// Throws a [NoticesException] listing every problem: a grammar with no
/// `license` field or no licence file at its root, a query file the
/// provenance does not list, or a compiled source outside `src/tree_sitter/`
/// whose comments mention a copyright without an `extraNotices` entry
/// naming it (and any `extraNotices` entry naming a file with no such
/// comment).
String thirdPartyNotices(NoticesInput input) {
  final problems = [...input.provenance.problems];
  final runtimeLicenses = _readLicenses(
    input.runtimeDirectory,
    runtimeLicenseFiles,
    'tree-sitter',
    problems,
  );
  problems.addAll(_runtimeCopyrightProblems(input.runtimeDirectory));
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
    ..write(_runtimeSection(input.toolchain, runtimeLicenses))
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
      'The query files written in tree-sitter-grammars, and the changes '
      'it made to the others, are covered by its own licence.\n\n',
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

String _runtimeSection(Toolchain toolchain, List<(String, String)> licenses) {
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
  return buffer.toString();
}

/// Reads [paths] under [directory], recording a problem for each that is
/// missing or not UTF-8.
List<(String, String)> _readLicenses(
  String directory,
  List<String> paths,
  String name,
  List<String> problems,
) {
  final licenses = <(String, String)>[];
  for (final path in paths) {
    final text = _readText(p.join(directory, path));
    if (text == null) {
      problems.add('$name: no readable $path');
    } else {
      licenses.add((path, text));
    }
  }
  return licenses;
}

String? _readText(String path) {
  final file = File(path);
  if (!file.existsSync()) return null;
  try {
    return utf8.decode(file.readAsBytesSync());
  } on FormatException {
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
  final licenseFiles = Directory(directory).existsSync()
      ? ([
          for (final entity in Directory(directory).listSync())
            if (entity is File &&
                licenseFilePattern.hasMatch(p.basename(entity.path)))
              p.basename(entity.path),
        ]..sort())
      : const <String>[];
  if (licenseFiles.isEmpty) {
    problems.add('$repository: no licence file at its root');
  }
  final builds = input.builds.where((build) => build.entry == entry).toList();
  final extraNotices = [...?(entry['extraNotices'] as List?)?.cast<String>()];
  final copyrighted = <String, List<String>>{};
  for (final build in builds) {
    final sourceDirectory = p.posix.normalize(p.posix.join(build.path, 'src'));
    for (final source in compiledSources(directory, sourceDirectory)) {
      final comments = copyrightComments(
        File(p.join(directory, source)).readAsStringSync(),
      );
      if (comments.isNotEmpty) copyrighted[source] = comments;
    }
  }
  for (final source in copyrighted.keys) {
    if (!extraNotices.contains(source)) {
      problems.add(
        '$repository: $source carries a copyright comment; name it in '
        'the entry\'s extraNotices',
      );
    }
  }
  for (final source in extraNotices) {
    if (!copyrighted.containsKey(source)) {
      problems.add(
        '$repository: extraNotices names $source, which no library '
        'compiles or which carries no copyright comment',
      );
    }
  }
  final deployedFrom = switch (entry['sourceCommit']) {
    final String source => ', deployed from $source',
    _ => '',
  };
  final buffer = StringBuffer()
    ..write('### $repository\n\n')
    ..write(
      '${_libraryList(builds)} from $url at ${entry['commit']}'
      '$deployedFrom. Licence: $license.\n\n',
    );
  for (final file in licenseFiles) {
    buffer.write(
      _fenced(file, _readText(p.join(directory, file)) ?? '', level: 4),
    );
  }
  for (final source in extraNotices) {
    final comments = copyrighted[source];
    if (comments == null) continue;
    buffer
      ..write(
        '#### $source\n\n'
        'The copyright comment${comments.length == 1 ? '' : 's'} of '
        '`$source`, which the library compiles in:\n\n',
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

/// Every problem with the runtime's compiled sources: a copyright comment
/// in a file outside `lib/src/unicode/`, whose licence the notices carry.
List<String> _runtimeCopyrightProblems(String runtimeDirectory) => [
  for (final source in includedFiles(runtimeDirectory, [
    'lib/src/lib.c',
  ], runtimeIncludeDirectories))
    if (!source.startsWith('lib/src/unicode/') &&
        copyrightComments(
          File(p.join(runtimeDirectory, source)).readAsStringSync(),
        ).isNotEmpty)
      'tree-sitter: $source carries a copyright comment the notices '
          'do not reproduce',
];

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

/// Every comment in the C source [text] that mentions a copyright, in
/// full, in order. String and character literals are skipped.
List<String> copyrightComments(String text) {
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
      final end = text.indexOf('\n', index);
      final stop = end < 0 ? text.length : end;
      comments.add(text.substring(index, stop));
      index = stop;
    } else {
      index++;
    }
  }
  return [
    for (final comment in comments)
      if (_copyright.hasMatch(comment)) comment,
  ];
}

String _querySection(
  Map<String, QueryProvenance> provenance,
  String Function(String) licenseOf,
) {
  final files = provenance.keys.toList()..sort();
  String name(String file) => file.substring('queries/'.length);
  String state(bool changed) =>
      changed ? 'modified in tree-sitter-grammars' : 'unchanged';
  final nvim = [
    for (final file in files)
      if (nvimSource(file, provenance[file]!) case final source?)
        '| `${name(file)}` | `${source.path}` | `${source.commit}` | '
            '${provenance[file]!.upstream!.repo == nvimTreesitterUrl ? state(provenance[file]!.changed) : 'by way of the grammar\'s file below'} |',
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
      'License 2.0 reproduced below. Each one names, in a header at its '
      'top, the nvim-treesitter file and commit it derives from and '
      'whether tree-sitter-grammars modified it.\n\n'
      '| File | nvim-treesitter file | Commit | State |\n'
      '| --- | --- | --- | --- |\n'
      '${nvim.join('\n')}\n\n'
      '### From a grammar\'s repository\n\n'
      'These files come from the repository of a grammar listed under '
      '"Grammars" above, under the licence reproduced there.\n\n'
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
