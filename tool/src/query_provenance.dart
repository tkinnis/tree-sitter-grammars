/// Reads and checks `tool/query_provenance.json`, the record of where each
/// query file under `queries/` came from.
///
/// The file maps each query path (for example `queries/c/highlights.scm`) to
/// an object with these fields:
///
/// - `origin`: `nvim` (nvim-treesitter), `grammar` (the grammar's own
///   repository), `both` (lines from each), or `here` (written in this
///   repository).
/// - `changed`: whether the file differs byte-for-byte from `upstream`.
///   Always false for `here`.
/// - `upstream`: the closest upstream file, as `{repo, commit, path}`, or
///   null for `here`.
/// - `nvimUpstream`: only on `both` entries whose closest upstream is the
///   grammar's repository; the closest nvim-treesitter file.
library;

import 'dart:convert';

/// Where a query file's text came from.
enum QueryOrigin { nvim, grammar, both, here }

/// One upstream file at one commit.
final class UpstreamFile {
  const UpstreamFile({
    required this.repo,
    required this.commit,
    required this.path,
  });

  /// The repository URL, for example
  /// `https://github.com/nvim-treesitter/nvim-treesitter`.
  final String repo;

  /// The 40-hex commit the file is read at.
  final String commit;

  /// The file's path inside [repo] at [commit].
  final String path;
}

/// The recorded provenance of one query file.
final class QueryProvenance {
  const QueryProvenance({
    required this.origin,
    required this.changed,
    this.upstream,
    this.nvimUpstream,
  });

  final QueryOrigin origin;
  final bool changed;
  final UpstreamFile? upstream;
  final UpstreamFile? nvimUpstream;
}

/// The result of reading the provenance file: its entries and every problem
/// found while reading them.
typedef ProvenanceReading = ({
  Map<String, QueryProvenance> entries,
  List<String> problems,
});

final _commitPattern = RegExp(r'^[0-9a-f]{40}$');
final _repoPattern = RegExp(r'^https://[^\s]+[^/\s]$');

/// Parses [json] and checks it against [queryFiles], the repository-relative
/// paths of every `.scm` file under `queries/`.
///
/// Every query file must have exactly one entry, and every entry must name an
/// existing query file. A duplicated key is reported even though a JSON
/// decoder would keep only its last value.
ProvenanceReading readQueryProvenance(
  String json,
  Iterable<String> queryFiles,
) {
  final problems = <String>[];
  final keyCounts = <String, int>{};
  final Object? decoded;
  try {
    decoded = jsonDecode(
      json,
      reviver: (key, value) {
        if (key is String && key.startsWith('queries/')) {
          keyCounts[key] = (keyCounts[key] ?? 0) + 1;
        }
        return value;
      },
    );
  } on FormatException catch (error) {
    return (entries: const {}, problems: ['not valid JSON: ${error.message}']);
  }
  if (decoded is! Map<String, Object?>) {
    return (entries: const {}, problems: ['the top level is not an object']);
  }
  for (final MapEntry(:key, :value) in keyCounts.entries) {
    if (value > 1) problems.add('$key: $value entries');
  }
  final entries = <String, QueryProvenance>{};
  for (final MapEntry(:key, :value) in decoded.entries) {
    final entry = _parseEntry(key, value, problems);
    if (entry != null) entries[key] = entry;
  }
  final files = queryFiles.toSet();
  for (final file in files.difference(decoded.keys.toSet()).toList()..sort()) {
    problems.add('$file: no entry');
  }
  for (final key in decoded.keys.toSet().difference(files).toList()..sort()) {
    problems.add('$key: entry names no query file');
  }
  return (entries: entries, problems: problems);
}

QueryProvenance? _parseEntry(
  String file,
  Object? value,
  List<String> problems,
) {
  if (value is! Map<String, Object?>) {
    problems.add('$file: not an object');
    return null;
  }
  const known = {'origin', 'changed', 'upstream', 'nvimUpstream'};
  for (final field in value.keys.where((field) => !known.contains(field))) {
    problems.add('$file: unknown field "$field"');
  }
  final origin = QueryOrigin.values.asNameMap()[value['origin']];
  final changed = value['changed'];
  if (origin == null) {
    problems.add('$file: origin must be one of '
        '${QueryOrigin.values.map((origin) => origin.name).join(', ')}');
  }
  if (changed is! bool) problems.add('$file: changed must be a boolean');
  final upstream =
      _parseUpstream(file, 'upstream', value['upstream'], problems);
  final nvimUpstream =
      _parseUpstream(file, 'nvimUpstream', value['nvimUpstream'], problems);
  if (origin == null || changed is! bool) return null;
  final isHere = origin == QueryOrigin.here;
  if (isHere && (upstream != null || changed)) {
    problems.add('$file: origin here takes no upstream and is never changed');
  }
  if (!isHere && upstream == null) {
    problems.add('$file: origin ${origin.name} needs an upstream');
  }
  if (nvimUpstream != null && origin != QueryOrigin.both) {
    problems.add('$file: nvimUpstream belongs only to origin both');
  }
  return QueryProvenance(
    origin: origin,
    changed: changed,
    upstream: upstream,
    nvimUpstream: nvimUpstream,
  );
}

UpstreamFile? _parseUpstream(
  String file,
  String field,
  Object? value,
  List<String> problems,
) {
  if (value == null) return null;
  if (value is! Map<String, Object?>) {
    problems.add('$file: $field must be an object or null');
    return null;
  }
  final repo = value['repo'];
  final commit = value['commit'];
  final path = value['path'];
  if (repo is! String || !_repoPattern.hasMatch(repo)) {
    problems.add('$file: $field.repo must be an https URL');
  }
  if (commit is! String || !_commitPattern.hasMatch(commit)) {
    problems.add('$file: $field.commit must be 40 lowercase hex digits');
  }
  if (path is! String || !path.endsWith('.scm')) {
    problems.add('$file: $field.path must name a .scm file');
  }
  if (value.length != 3) {
    problems.add('$file: $field takes exactly repo, commit and path');
  }
  if (repo is! String || commit is! String || path is! String) return null;
  return UpstreamFile(repo: repo, commit: commit, path: path);
}
