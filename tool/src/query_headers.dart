/// Writes and checks the header every query file derived from nvim-treesitter
/// carries, as section 4(b) of the Apache License 2.0 asks of a
/// redistributed file.
///
/// The header is the file's first lines, followed by one blank line:
///
/// ```scheme
/// ; Derived from nvim-treesitter <url>, <path> @ <commit>, Apache-2.0.
/// ; Modified in tree-sitter-grammars.
/// ```
///
/// where `<url>` is [nvimTreesitterUrl] and `<path>` the file's path in
/// nvim-treesitter at `<commit>`, for example
/// `runtime/queries/c/highlights.scm`.
///
/// A file whose closest upstream is a grammar's own repository, which in turn
/// carries nvim-treesitter's lines, names both, the grammar's file second:
///
/// ```scheme
/// ; Derived from nvim-treesitter <url>, <path> @ <commit>, Apache-2.0.
/// ; Taken from <grammar url>, <path> @ <commit>, <licence>.
/// ; Unchanged.
/// ```
///
/// The last line says whether the file differs from the upstream file named
/// last, as `tool/query_provenance.json` records it.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import 'grammar_pins.dart';
import 'query_provenance.dart';

/// The repository every nvim-derived header names.
const nvimTreesitterUrl = 'https://github.com/nvim-treesitter/nvim-treesitter';

const _derivedPrefix = '; Derived from nvim-treesitter ';
const _takenPrefix = '; Taken from ';
const _modified = '; Modified in tree-sitter-grammars.';
const _unchanged = '; Unchanged.';

/// Thrown when a query file's provenance cannot produce a header.
final class QueryHeaderException implements Exception {
  const QueryHeaderException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Whether [provenance] names nvim-treesitter, so its file carries a header.
bool isNvimDerived(QueryProvenance provenance) =>
    provenance.origin == QueryOrigin.nvim ||
    provenance.origin == QueryOrigin.both;

/// The nvim-treesitter file [provenance] derives from, or null when it
/// derives from none.
///
/// Throws a [QueryHeaderException] for an nvim-derived entry that names no
/// nvim-treesitter file.
UpstreamFile? nvimSource(String file, QueryProvenance provenance) {
  if (!isNvimDerived(provenance)) return null;
  final upstream = provenance.upstream;
  if (upstream != null && upstream.repo == nvimTreesitterUrl) return upstream;
  final nvim = provenance.nvimUpstream;
  if (nvim != null && nvim.repo == nvimTreesitterUrl) return nvim;
  throw QueryHeaderException(
    '$file: origin ${provenance.origin.name} names no nvim-treesitter file',
  );
}

/// The header lines of [file], or an empty list for a file that derives
/// from nothing in nvim-treesitter.
///
/// [licenseOf] answers the licence of a grammar repository by its URL, for a
/// file whose closest upstream is that grammar's repository.
List<String> queryHeader(
  String file,
  QueryProvenance provenance,
  String Function(String repository) licenseOf,
) {
  final nvim = nvimSource(file, provenance);
  if (nvim == null) return const [];
  final upstream = provenance.upstream!;
  return [
    '$_derivedPrefix$nvimTreesitterUrl, ${nvim.path} @ ${nvim.commit}, '
        'Apache-2.0.',
    if (upstream.repo != nvimTreesitterUrl)
      '$_takenPrefix${upstream.repo}, ${upstream.path} @ '
          '${upstream.commit}, ${licenseOf(upstream.repo)}.',
    provenance.changed ? _modified : _unchanged,
  ];
}

/// The number of leading lines of [lines] that form a header of the shape
/// [queryHeader] writes, whatever it names.
int _headerLength(List<String> lines) {
  if (lines.isEmpty || !lines.first.startsWith(_derivedPrefix)) return 0;
  var length = 1;
  if (length < lines.length && lines[length].startsWith(_takenPrefix)) {
    length++;
  }
  if (length < lines.length &&
      (lines[length] == _modified || lines[length] == _unchanged)) {
    return length + 1;
  }
  return 0;
}

/// The first line of a header naming an nvim-treesitter file and no grammar
/// repository, capturing the file's path and commit.
final _nvimDerivedLine = RegExp(
  '^${RegExp.escape('$_derivedPrefix$nvimTreesitterUrl, ')}'
  r'(.+\.scm) @ ([0-9a-f]{40}), Apache-2\.0\.$',
);

/// The nvim-treesitter file [content]'s header names when that header says
/// the file is unchanged from it and names no grammar repository, as
/// [queryHeader] writes one; null for any other header, or none.
UpstreamFile? unchangedNvimSource(String content) {
  final lines = content.split('\n');
  if (_headerLength(lines) != 2 || lines[1] != _unchanged) return null;
  final match = _nvimDerivedLine.firstMatch(lines.first);
  if (match == null) return null;
  return UpstreamFile(
    repo: nvimTreesitterUrl,
    commit: match[2]!,
    path: match[1]!,
  );
}

/// [content] with its header replaced by [header]: any header already at
/// its top, and the blank line after it, are removed first. An empty
/// [header] leaves the file with none.
String withQueryHeader(String content, List<String> header) {
  final lines = content.split('\n');
  var start = _headerLength(lines);
  if (start > 0 && start < lines.length && lines[start].isEmpty) start++;
  final body = lines.skip(start).join('\n');
  return header.isEmpty ? body : '${header.join('\n')}\n\n$body';
}

/// Every way [content] departs from carrying exactly [header]: a missing or
/// different header, or a header line anywhere else in the file.
List<String> queryHeaderProblems(
  String file,
  String content,
  List<String> header,
) {
  final expected = withQueryHeader(content, header);
  final strays = content
      .split('\n')
      .skip(_headerLength(content.split('\n')))
      .where((line) => line.startsWith(_derivedPrefix));
  return [
    if (expected != content)
      header.isEmpty
          ? '$file: carries an nvim-treesitter header its provenance does '
                'not name'
          : '$file: does not start with the header its provenance names',
    if (strays.isNotEmpty)
      '$file: names nvim-treesitter below its header: ${strays.first}',
  ];
}

/// Answers the `license` of the grammar in [entries] whose `url` is a
/// repository's URL, throwing a [QueryHeaderException] for a repository no
/// entry names.
String Function(String repository) licenseLookup(
  List<Map<String, Object?>> entries,
) {
  final licenses = {
    for (final entry in entries)
      if (entry['url'] case final String url)
        normalizeRepositoryUrl(url): entry['license'],
  };
  return (repository) => switch (licenses[normalizeRepositoryUrl(repository)]) {
    final String license => license,
    _ => throw QueryHeaderException(
      '$repository is not a grammar in grammars.json with a license',
    ),
  };
}

/// Every query file of [provenance] under [root] whose header is not the
/// one its entry names.
List<String> queryHeaderCheck(
  String root,
  Map<String, QueryProvenance> provenance,
  String Function(String repository) licenseOf,
) {
  final problems = <String>[];
  for (final MapEntry(key: file, value: entry) in provenance.entries) {
    try {
      problems.addAll(
        queryHeaderProblems(
          file,
          File(p.join(root, file)).readAsStringSync(),
          queryHeader(file, entry, licenseOf),
        ),
      );
    } on QueryHeaderException catch (error) {
      problems.add('$error');
    }
  }
  return problems;
}

/// Gives every query file of [provenance] under [root] the header its entry
/// names, and returns the files that changed.
List<String> writeQueryHeaders(
  String root,
  Map<String, QueryProvenance> provenance,
  String Function(String repository) licenseOf,
) {
  final changed = <String>[];
  for (final MapEntry(key: file, value: entry) in provenance.entries) {
    final query = File(p.join(root, file));
    final content = query.readAsStringSync();
    final updated = withQueryHeader(
      content,
      queryHeader(file, entry, licenseOf),
    );
    if (updated != content) {
      query.writeAsStringSync(updated);
      changed.add(file);
    }
  }
  return changed..sort();
}
