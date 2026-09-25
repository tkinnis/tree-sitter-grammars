/// Imports a language's query files from nvim-treesitter at one commit,
/// giving each the header and the `tool/query_provenance.json` entry that
/// name that commit.
///
/// [planBootstrap] reads and checks everything a run writes before
/// anything is written, and [writeBootstrap] writes what it planned. Every
/// git command runs with [runIsolatedGit] or [runIsolatedGitBytes], so no
/// refspec, URL rewrite or other setting of the user's or the system's
/// takes part.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'git.dart';
import 'grammar_sources.dart';
import 'query_headers.dart';
import 'query_provenance.dart';

/// The query types imported from nvim-treesitter, in the order they are
/// reported.
const nvimQueryTypes = [
  'highlights',
  'folds',
  'injections',
  'locals',
  'indents',
];

/// Language ids whose nvim-treesitter directory has another name.
const _nvimLanguageNames = {'c-sharp': 'c_sharp'};

/// The ref origin's `HEAD` is fetched into.
const _originHead = 'refs/origin-head';

/// The namespace origin's branches are fetched into, and the only refs
/// that vouch for a commit: no configured refspec writes here.
const _originBranches = 'refs/origin-branches/';

/// Thrown when nvim-treesitter cannot supply a language's queries, or when
/// what a bootstrap would write fails a check.
final class BootstrapException implements Exception {
  /// A refusal that [message] explains.
  const BootstrapException(this.message);

  /// What was refused and why, with one problem per line.
  final String message;

  @override
  String toString() => message;
}

/// What the command line asks a bootstrap to do.
typedef BootstrapRequest = ({
  String language,
  String? commit,
  bool force,
  bool dryRun,
});

/// Reads the arguments of `tool/bootstrap_language.dart`, or returns null
/// when they are not a command it takes.
///
/// `--language=<name>` is required and must be a lowercase id; `--commit`
/// must be 40 lowercase hex digits; each option may appear once.
BootstrapRequest? parseBootstrapArguments(List<String> args) {
  String? language;
  String? commit;
  var force = false;
  var dryRun = false;
  for (final arg in args) {
    if (arg.startsWith('--language=') && language == null) {
      language = arg.substring('--language='.length);
    } else if (arg.startsWith('--commit=') && commit == null) {
      commit = arg.substring('--commit='.length);
    } else if (arg == '--force' && !force) {
      force = true;
    } else if (arg == '--dry-run' && !dryRun) {
      dryRun = true;
    } else {
      return null;
    }
  }
  if (language == null || !RegExp(r'^[a-z0-9_-]+$').hasMatch(language)) {
    return null;
  }
  if (commit != null && !RegExp(r'^[0-9a-f]{40}$').hasMatch(commit)) {
    return null;
  }
  return (language: language, commit: commit, force: force, dryRun: dryRun);
}

/// One query file read from nvim-treesitter, ready to write.
final class ImportedQuery {
  /// The import of [file], whose [content] carries the header [provenance]
  /// names.
  const ImportedQuery({
    required this.file,
    required this.content,
    required this.provenance,
  });

  /// The file's repository-relative path, for example
  /// `queries/rust/highlights.scm`.
  final String file;

  /// The upstream file's text under the header [provenance] names.
  final String content;

  /// The file's `tool/query_provenance.json` entry.
  final Map<String, Object?> provenance;
}

/// The directory under [root] that holds nvim-treesitter's git objects.
String nvimStoreDirectory(String root) =>
    p.join(root, '.cache', 'nvim-treesitter');

/// The directories [language]'s queries have had inside nvim-treesitter,
/// the current layout first: `runtime/queries/<name>`, and `queries/<name>`
/// in commits from before the queries moved.
List<String> nvimQueryDirectories(String language) {
  final name = _nvimName(language);
  return ['runtime/queries/$name', 'queries/$name'];
}

/// The name nvim-treesitter gives [language].
String _nvimName(String language) => _nvimLanguageNames[language] ?? language;

/// The other spellings of [language] that name the same nvim-treesitter
/// language: its nvim-treesitter name, and every language id that
/// [_nvimLanguageNames] maps to that name; sorted.
List<String> _otherSpellings(String language) {
  final name = _nvimName(language);
  return {
    name,
    for (final MapEntry(key: id, value: nvimName) in _nvimLanguageNames.entries)
      if (nvimName == name) id,
  }.where((spelling) => spelling != language).toList()..sort();
}

/// Fetches origin's `HEAD` and every branch of origin, with their whole
/// history, into the object store [store] whose origin is [url], and
/// returns [commit], or origin's `HEAD` when it is null.
///
/// The branches land in a namespace of this tool's own, pruned on every
/// fetch, and [commit] is accepted only when one of them contains it, so a
/// commit that only a fork, a pull request or a deleted branch carries is
/// never recorded as nvim-treesitter's. A store an earlier fetch left
/// shallow is completed. [url] is nvim-treesitter's unless a test supplies
/// its own repository.
///
/// Throws a [BootstrapException] for a commit no branch of origin contains,
/// an object that is not a commit, or a partial clone (whose missing
/// objects git would fetch one at a time); a [GrammarSourceException] when
/// [store] is not a store of [url]; and a [GitException] when a git
/// command fails.
Future<String> fetchNvimCommit(
  String store, {
  String? commit,
  String url = nvimTreesitterUrl,
}) async {
  await ensureObjectStore(runIsolatedGit, store, url);
  for (final key in ['extensions.partialclone', 'remote.origin.promisor']) {
    if (await _config(store, key) != null) {
      throw BootstrapException(
        '$store is a partial clone ($key is set), whose missing objects '
        'git fetches one at a time; delete it and run again',
      );
    }
  }
  final shallow =
      (await runIsolatedGit(store, [
        'rev-parse',
        '--is-shallow-repository',
      ])).trim() ==
      'true';
  await runIsolatedGit(store, [
    'fetch',
    '--quiet',
    '--prune',
    '--no-tags',
    if (shallow) '--unshallow',
    'origin',
    '+HEAD:$_originHead',
    '+refs/heads/*:$_originBranches*',
  ]);
  final wanted =
      commit ??
      (await runIsolatedGit(store, ['rev-parse', _originHead])).trim();
  if (!await _onOriginBranch(store, wanted)) {
    throw BootstrapException(
      'nvim-treesitter: no branch on origin contains $wanted',
    );
  }
  return wanted;
}

/// The value of [key] in [store]'s own configuration, or null when unset.
Future<String?> _config(String store, String key) async {
  try {
    return (await runIsolatedGit(store, ['config', '--get', key])).trim();
  } on GitException catch (error) {
    if (error.exitCode == 1) return null;
    rethrow;
  }
}

/// Whether a branch of origin, as the last fetch into [store] left them,
/// contains [commit]. Only a missing object answers false without asking
/// the branches; every other git failure propagates.
Future<bool> _onOriginBranch(String store, String commit) async {
  try {
    await runIsolatedGit(store, ['cat-file', '-e', commit]);
  } on GitException catch (error) {
    if (error.exitCode == 1) return false;
    rethrow;
  }
  final type = (await runIsolatedGit(store, ['cat-file', '-t', commit])).trim();
  if (type != 'commit') {
    throw BootstrapException('nvim-treesitter: $commit is a $type');
  }
  final branches = await runIsolatedGit(store, [
    'for-each-ref',
    '--contains',
    commit,
    '--format=%(refname)',
    _originBranches,
  ]);
  return branches.trim().isNotEmpty;
}

/// [language]'s query files of the [nvimQueryTypes] that nvim-treesitter
/// has at [commit] in [store], each with the header and provenance entry of
/// a file imported unchanged.
///
/// The files are read from the first of [nvimQueryDirectories] that
/// [commit] has, each as the exact bytes [commit] holds, decoded as strict
/// UTF-8. Throws a [BootstrapException] when [commit] has none of those
/// directories, when the directory holds none of the [nvimQueryTypes], or
/// when a file is not UTF-8 text.
Future<List<ImportedQuery>> importNvimQueries({
  required String store,
  required String commit,
  required String language,
}) async {
  final candidates = nvimQueryDirectories(language);
  var directory = candidates.first;
  var listed = <String>{};
  for (final candidate in candidates) {
    directory = candidate;
    listed = (await runIsolatedGit(store, [
      'ls-tree',
      '-z',
      '--name-only',
      commit,
      '--',
      '$candidate/',
    ])).split('\x00').where((path) => path.isNotEmpty).toSet();
    if (listed.isNotEmpty) break;
  }
  if (listed.isEmpty) {
    throw BootstrapException(
      'nvim-treesitter has no ${candidates.join('/ or ')}/ at $commit',
    );
  }
  final imports = [
    for (final type in nvimQueryTypes)
      if (listed.contains('$directory/$type.scm'))
        ImportedQuery(
          file: 'queries/$language/$type.scm',
          content: withQueryHeader(
            await _readText(store, commit, '$directory/$type.scm'),
            _nvimHeader(
              'queries/$language/$type.scm',
              commit,
              '$directory/$type.scm',
            ),
          ),
          provenance: _nvimProvenance(commit, '$directory/$type.scm'),
        ),
  ];
  if (imports.isEmpty) {
    throw BootstrapException(
      'nvim-treesitter has none of ${nvimQueryTypes.join(', ')} in '
      '$directory/ at $commit',
    );
  }
  return imports;
}

/// The text of [path] at [commit] in [store], decoded as strict UTF-8.
Future<String> _readText(String store, String commit, String path) async {
  final bytes = await runIsolatedGitBytes(store, [
    'cat-file',
    'blob',
    '$commit:$path',
  ]);
  try {
    return utf8.decode(bytes);
  } on FormatException {
    throw BootstrapException('$path at $commit is not UTF-8 text');
  }
}

/// The header of [file], imported unchanged from [path] at [commit].
List<String> _nvimHeader(String file, String commit, String path) =>
    queryHeader(
      file,
      QueryProvenance(
        origin: QueryOrigin.nvim,
        changed: false,
        upstream: UpstreamFile(
          repo: nvimTreesitterUrl,
          commit: commit,
          path: path,
        ),
      ),
      _noGrammarLicense,
    );

/// The provenance entry of a file imported unchanged from [path] at
/// [commit].
Map<String, Object?> _nvimProvenance(String commit, String path) => {
  'origin': QueryOrigin.nvim.name,
  'changed': false,
  'upstream': {'repo': nvimTreesitterUrl, 'commit': commit, 'path': path},
};

/// A bootstrap writes only files from nvim-treesitter or written here, whose
/// headers name no grammar repository.
String _noGrammarLicense(String repository) => throw BootstrapException(
  '$repository: a bootstrap writes no file taken from a grammar repository',
);

/// The provenance entry of a query file written in this repository.
const Map<String, Object?> writtenHereProvenance = {
  'origin': 'here',
  'changed': false,
  'upstream': null,
};

/// The `tags.scm` a bootstrap writes where a language has none.
const tagsPlaceholder =
    '; Symbol patterns for code navigation, written in this repository.\n';

/// [json], the text of `tool/query_provenance.json`, with [entries] set,
/// the entries of [removed] dropped and its files sorted, encoded as that
/// file is written; the fields inside each entry keep their order.
String withProvenanceEntries(
  String json,
  Map<String, Map<String, Object?>> entries, {
  Iterable<String> removed = const [],
}) {
  final merged = {...jsonDecode(json) as Map<String, Object?>, ...entries};
  removed.forEach(merged.remove);
  final sorted = {
    for (final file in merged.keys.toList()..sort()) file: merged[file],
  };
  return '${const JsonEncoder.withIndent('  ').convert(sorted)}\n';
}

/// Everything one bootstrap writes and removes under the repository root.
final class BootstrapPlan {
  /// The plan of a bootstrap at [commit].
  const BootstrapPlan({
    required this.commit,
    required this.files,
    required this.entries,
    required this.removals,
    required this.provenanceJson,
    required this.seen,
  });

  /// The nvim-treesitter commit the queries are read at.
  final String commit;

  /// Each file to write, by repository-relative path: the imported query
  /// files in [nvimQueryTypes] order, then the `tags.scm` placeholder and
  /// the `config.json` skeleton where the language has none.
  final Map<String, String> files;

  /// The `tool/query_provenance.json` entry of each query file in [files].
  final Map<String, Map<String, Object?>> entries;

  /// Earlier unchanged imports of a query type [commit] no longer has,
  /// removed with their entries.
  final List<String> removals;

  /// The text `tool/query_provenance.json` is rewritten to.
  final String provenanceJson;

  /// The text of every path the plan was made from, read once before
  /// nvim-treesitter was fetched: `tool/query_provenance.json` and each
  /// file a bootstrap writes or removes, null where there was none.
  /// [writeBootstrap] refuses to write over a change.
  final Map<String, String?> seen;
}

/// Plans [request] with [planBootstrap], hands the plan to [beforeWriting]
/// and, unless it is a dry run, writes it with [writeBootstrap]; returns
/// the plan.
Future<BootstrapPlan> bootstrap({
  required String root,
  required BootstrapRequest request,
  String url = nvimTreesitterUrl,
  void Function(BootstrapPlan plan)? beforeWriting,
}) async {
  final plan = await planBootstrap(root: root, request: request, url: url);
  beforeWriting?.call(plan);
  if (!request.dryRun) writeBootstrap(root, plan);
  return plan;
}

const _provenanceFile = 'tool/query_provenance.json';

/// Plans importing [request]'s language into the repository at [root] from
/// nvim-treesitter (at [url] when a test supplies its own), writing nothing
/// but nvim-treesitter's objects into [nvimStoreDirectory].
///
/// Every path the plan depends on is read once, before the fetch, and
/// must be a file or absent. Nothing may exist under `queries/` at
/// another spelling of the language, one that nvim-treesitter names the
/// same, such as `c_sharp` beside `c-sharp`, with or without `force`,
/// since the run would write the language a second directory. Without
/// `force`, `queries/<language>/` must
/// not exist and `tool/query_provenance.json` must have no problem. With
/// it, a file a bootstrap writes that has no entry, as a run stopped
/// before its entries leaves one, is allowed; an existing file is
/// replaced only when it is what a bootstrap wrote there: already the
/// planned text, the placeholder `tags.scm`, or an unchanged import, whose
/// text is still the upstream file its entry or its own header names under
/// that header. Such an import of a query type the commit no longer has is
/// removed. A `config.json` and every other file are kept.
///
/// Throws a [BootstrapException] for each refusal, and when the planned
/// files and entries would fail the provenance or header check;
/// nvim-treesitter's refusals propagate from [fetchNvimCommit] and
/// [importNvimQueries].
Future<BootstrapPlan> planBootstrap({
  required String root,
  required BootstrapRequest request,
  String url = nvimTreesitterUrl,
}) async {
  final directory = 'queries/${request.language}';
  switch (FileSystemEntity.typeSync(
    p.join(root, directory),
    followLinks: false,
  )) {
    case FileSystemEntityType.notFound || FileSystemEntityType.directory:
      break;
    default:
      throw BootstrapException('$directory is not a directory');
  }
  for (final spelling in _otherSpellings(request.language)) {
    if (FileSystemEntity.typeSync(
          p.join(root, 'queries', spelling),
          followLinks: false,
        ) !=
        FileSystemEntityType.notFound) {
      throw BootstrapException(
        'queries/$spelling/ holds the language nvim-treesitter names '
        '${_nvimName(request.language)}; bootstrap it with '
        '--language=$spelling',
      );
    }
  }
  if (Directory(p.join(root, directory)).existsSync() && !request.force) {
    throw BootstrapException(
      '$directory/ exists; --force replaces the files a bootstrap wrote',
    );
  }
  final seen = _readInputs(root, directory);
  final current =
      seen[_provenanceFile] ??
      (throw const BootstrapException('$_provenanceFile is missing'));
  final recorded = _recordedProvenance(root, current, directory, request);
  final store = nvimStoreDirectory(root);
  final commit = await fetchNvimCommit(store, commit: request.commit, url: url);
  final imports = await importNvimQueries(
    store: store,
    commit: commit,
    language: request.language,
  );
  final (:files, :entries) = _plannedFiles(imports, request.language, seen);
  await _requireOnlyBootstrapWork(store, files, seen, recorded);
  final removals = await _removals(store, directory, files, seen, recorded);
  final plan = BootstrapPlan(
    commit: commit,
    files: files,
    entries: entries,
    removals: removals,
    provenanceJson: withProvenanceEntries(current, entries, removed: removals),
    seen: seen,
  );
  _requireNone('the planned query files', _planProblems(root, plan));
  return plan;
}

/// The files a bootstrap writes under [directory]: one per query type and
/// the `tags.scm` placeholder.
List<String> _bootstrapQueryFiles(String directory) => [
  for (final type in nvimQueryTypes) '$directory/$type.scm',
  '$directory/tags.scm',
];

/// The text of every path a bootstrap of [directory] reads or writes.
Map<String, String?> _readInputs(String root, String directory) => {
  for (final file in [
    ..._bootstrapQueryFiles(directory),
    '$directory/config.json',
    _provenanceFile,
  ])
    file: _readFile(root, file),
};

/// The text of [file] under [root], or null when nothing is there. Throws a
/// [BootstrapException] when something other than a file is there, such as
/// a directory or a link.
String? _readFile(String root, String file) {
  final path = p.join(root, file);
  return switch (FileSystemEntity.typeSync(path, followLinks: false)) {
    FileSystemEntityType.notFound => null,
    FileSystemEntityType.file => File(path).readAsStringSync(),
    _ => throw BootstrapException('$file is not a file'),
  };
}

/// The entries of [json], the text of `tool/query_provenance.json`, after
/// requiring it to have no problem. With `force`, a file a bootstrap of
/// [directory] writes that exists with no entry is left out of the check,
/// as a run stopped before its entries leaves one; the plan's own check
/// covers it.
Map<String, QueryProvenance> _recordedProvenance(
  String root,
  String json,
  String directory,
  BootstrapRequest request,
) {
  final files = repositoryQueryFiles(root);
  final unrecorded = request.force
      ? _unrecorded(json, _bootstrapQueryFiles(directory))
      : const <String>{};
  final reading = readQueryProvenance(
    json,
    files.where((file) => !unrecorded.contains(file)),
  );
  _requireNone('$_provenanceFile has problems to fix first', reading.problems);
  return reading.entries;
}

/// The members of [files] that [json] has no key for; none when [json] is
/// not a JSON object, whose problems the check reports.
Set<String> _unrecorded(String json, List<String> files) {
  final Object? decoded;
  try {
    decoded = jsonDecode(json);
  } on FormatException {
    return const {};
  }
  if (decoded is! Map<String, Object?>) return const {};
  return {
    for (final file in files)
      if (!decoded.containsKey(file)) file,
  };
}

/// The files and entries a bootstrap of [language] writes, given [seen].
({Map<String, String> files, Map<String, Map<String, Object?>> entries})
_plannedFiles(
  List<ImportedQuery> imports,
  String language,
  Map<String, String?> seen,
) {
  final files = {for (final query in imports) query.file: query.content};
  final entries = {for (final query in imports) query.file: query.provenance};
  final tags = 'queries/$language/tags.scm';
  if (seen[tags] case null || tagsPlaceholder) {
    files[tags] = tagsPlaceholder;
    entries[tags] = writtenHereProvenance;
  }
  final config = 'queries/$language/config.json';
  if (seen[config] == null) files[config] = configSkeleton(language);
  return (files: files, entries: entries);
}

/// Throws a [BootstrapException] naming every file of [files] that exists
/// and holds something other than what a bootstrap wrote there.
Future<void> _requireOnlyBootstrapWork(
  String store,
  Map<String, String> files,
  Map<String, String?> seen,
  Map<String, QueryProvenance> recorded,
) async => _requireNone(
  '--force replaces only what a bootstrap wrote; these files hold other '
  'work',
  [
    for (final MapEntry(key: file, value: planned) in files.entries)
      if (seen[file] case final text?
          when text != planned &&
              !await _isUnchangedImport(store, file, text, recorded[file]))
        file,
  ],
);

/// The unchanged imports under [directory] of a query type [files] does
/// not write, which the commit no longer has.
Future<List<String>> _removals(
  String store,
  String directory,
  Map<String, String> files,
  Map<String, String?> seen,
  Map<String, QueryProvenance> recorded,
) async => [
  for (final type in nvimQueryTypes)
    if ('$directory/$type.scm' case final file when !files.containsKey(file))
      if (seen[file] case final text?
          when await _isUnchangedImport(store, file, text, recorded[file]))
        file,
];

/// Whether [text] is exactly an unchanged nvim-treesitter import of the
/// file a bootstrap reads for [file]: the same query type of the same
/// language, in either of [nvimQueryDirectories].
///
/// [entry], [file]'s provenance, must be absent or record an unchanged
/// import; an entry recording anything else means other work. The upstream
/// file the entry names is tried, then the one [text]'s own header names,
/// since a run stopped before its entries leaves a newer import under an
/// older entry or none.
Future<bool> _isUnchangedImport(
  String store,
  String file,
  String text,
  QueryProvenance? entry,
) async {
  final type = p.posix.basename(file);
  final language = p.posix.basename(p.posix.dirname(file));
  final readable = {
    for (final directory in nvimQueryDirectories(language)) '$directory/$type',
  };
  final UpstreamFile? recordedSource;
  switch (entry) {
    case null:
      recordedSource = null;
    case QueryProvenance(
          origin: QueryOrigin.nvim,
          changed: false,
          :final upstream?,
        )
        when upstream.repo == nvimTreesitterUrl:
      recordedSource = upstream;
    default:
      return false;
  }
  final tried = <String>{};
  for (final source in [?recordedSource, ?unchangedNvimSource(text)]) {
    if (!readable.contains(source.path)) continue;
    if (!tried.add('${source.commit}:${source.path}')) continue;
    if (await _isImportOf(store, file, text, source)) return true;
  }
  return false;
}

/// Whether [text] is [source]'s file under the header naming it. A commit
/// [store] lacks, a path the commit lacks, and a file that is not UTF-8
/// text all answer false; every other git failure propagates.
Future<bool> _isImportOf(
  String store,
  String file,
  String text,
  UpstreamFile source,
) async {
  try {
    await runIsolatedGit(store, ['cat-file', '-e', source.commit]);
  } on GitException catch (error) {
    if (error.exitCode == 1) return false;
    rethrow;
  }
  final listed = await runIsolatedGit(store, [
    'ls-tree',
    '--name-only',
    source.commit,
    '--',
    source.path,
  ]);
  if (listed.trim() != source.path) return false;
  final String original;
  try {
    original = await _readText(store, source.commit, source.path);
  } on BootstrapException {
    return false;
  }
  return text ==
      withQueryHeader(original, _nvimHeader(file, source.commit, source.path));
}

/// Every provenance and header problem [plan] would leave in [root].
List<String> _planProblems(String root, BootstrapPlan plan) {
  final reading = readQueryProvenance(plan.provenanceJson, {
    ...repositoryQueryFiles(
      root,
    ).where((file) => !plan.removals.contains(file)),
    ...plan.files.keys.where((file) => file.endsWith('.scm')),
  });
  return [
    ...reading.problems,
    for (final file in plan.entries.keys)
      if (reading.entries[file] case final entry?)
        ...queryHeaderProblems(
          file,
          plan.files[file]!,
          queryHeader(file, entry, _noGrammarLicense),
        ),
  ];
}

void _requireNone(String what, List<String> problems) {
  if (problems.isEmpty) return;
  throw BootstrapException([what, ...problems].join('\n  '));
}

/// Writes every file of [plan] under [root], then
/// `tool/query_provenance.json`, then removes [BootstrapPlan.removals].
///
/// It refuses, writing nothing, when any path in [BootstrapPlan.seen] no
/// longer holds the text the plan was made from. Each file is written into
/// a directory under `.cache/` and renamed into place, so none is ever
/// left half written and no temporary file is left beside it. A run
/// stopped part way leaves files the entries do not yet describe, or files
/// the entries no longer name; `--force` plans the same work again from
/// either.
void writeBootstrap(String root, BootstrapPlan plan) {
  _requireNone('changed since the bootstrap was planned; run it again', [
    for (final MapEntry(key: file, value: text) in plan.seen.entries)
      if (_readFile(root, file) != text) file,
  ]);
  // A run killed before its finally block leaves this directory behind;
  // it holds nothing a later run needs.
  final staging = Directory(p.join(root, '.cache', 'bootstrap-staging'));
  if (staging.existsSync()) staging.deleteSync(recursive: true);
  staging.createSync(recursive: true);
  try {
    var index = 0;
    void replace(String file, String content) {
      final target = File(p.join(root, file));
      target.parent.createSync(recursive: true);
      File(p.join(staging.path, '${index++}'))
        ..writeAsStringSync(content, flush: true)
        ..renameSync(target.path);
    }

    plan.files.forEach(replace);
    replace(_provenanceFile, plan.provenanceJson);
    for (final file in plan.removals) {
      File(p.join(root, file)).deleteSync();
    }
  } finally {
    staging.deleteSync(recursive: true);
  }
}

/// A `config.json` for [language] to edit: its symbol, scope and one file
/// extension named after it, C-style comments and the common brackets.
String configSkeleton(String language) {
  final displayName = language[0].toUpperCase() + language.substring(1);
  return '''{
  "displayName": "$displayName",
  "symbol": "${language.replaceAll('-', '_')}",
  "scope": "source.$language",
  "extensions": [
    ".$language"
  ],
  "comments": {
    "line": "//",
    "block": ["/*", "*/"]
  },
  "brackets": [
    {"open": "{", "close": "}", "autoClose": true, "newline": true},
    {"open": "(", "close": ")", "autoClose": true, "newline": false},
    {"open": "[", "close": "]", "autoClose": true, "newline": false},
    {"open": "\\"", "close": "\\"", "autoClose": true, "newline": false},
    {"open": "'", "close": "'", "autoClose": true, "newline": false}
  ]
}
''';
}
