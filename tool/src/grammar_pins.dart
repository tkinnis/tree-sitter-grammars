/// Reads, checks and rewrites the pins in `tool/grammars.json`.
///
/// Every entry with a `url` builds a grammar and carries:
///
/// - `commit`: the 40-hex upstream commit the build extracts.
/// - `sourceCommit` (optional): the commit on the upstream's source branch
///   that `commit` was deployed from, for a pin on a deploy branch.
/// - `license`: the SPDX identifier of the grammar's licence.
/// - `generate` (optional): true when the grammar commits no `src/parser.c`
///   and the build generates it from `src/grammar.json`.
/// - `extraNotices` (optional): source files carrying a copyright notice of
///   their own, beyond the grammar's licence file.
library;

import 'dart:convert';

import 'git.dart';

final _commitPattern = RegExp(r'^[0-9a-f]{40}$');

/// The pin fields, in the order they follow `url` in each entry.
const pinFields = [
  'commit',
  'sourceCommit',
  'license',
  'generate',
  'extraNotices',
];

/// The last path segment of [url] without a `.git` suffix, which is also the
/// grammar's directory under `grammars/`.
String repositoryName(String url) =>
    normalizeRepositoryUrl(url).split('/').last;

/// [url] without a trailing `/` or `.git`, so two spellings of one GitHub
/// repository compare equal.
String normalizeRepositoryUrl(String url) {
  var normalized = url.trim();
  while (normalized.endsWith('/')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  if (normalized.endsWith('.git')) {
    normalized = normalized.substring(0, normalized.length - 4);
  }
  return normalized;
}

/// Parses `tool/grammars.json`.
List<Map<String, Object?>> parseGrammars(String json) => [
  for (final entry in jsonDecode(json) as List<Object?>)
    entry! as Map<String, Object?>,
];

/// Encodes [entries] as `tool/grammars.json` is written: two-space indent,
/// a trailing newline, and the pin fields directly after `url`.
String encodeGrammars(List<Map<String, Object?>> entries) {
  final ordered = [
    for (final entry in entries)
      {
        if (entry.containsKey('url')) 'url': entry['url'],
        for (final field in pinFields)
          if (entry.containsKey(field)) field: entry[field],
        for (final MapEntry(:key, :value) in entry.entries)
          if (key != 'url' && !pinFields.contains(key)) key: value,
      },
  ];
  return '${const JsonEncoder.withIndent('  ').convert(ordered)}\n';
}

/// Every problem with the pin fields of [entries]; empty when each url entry
/// is fully pinned.
List<String> pinProblems(List<Map<String, Object?>> entries) {
  final problems = <String>[];
  final seen = <String>{};
  for (final entry in entries) {
    final url = entry['url'];
    if (url == null) continue;
    if (url is! String) {
      problems.add('an entry has a url that is not a string');
      continue;
    }
    final name = repositoryName(url);
    if (!seen.add(normalizeRepositoryUrl(url))) {
      problems.add('$name: listed more than once');
    }
    final commit = entry['commit'];
    if (commit is! String || !_commitPattern.hasMatch(commit)) {
      problems.add('$name: commit must be 40 lowercase hex digits');
    }
    final sourceCommit = entry['sourceCommit'];
    if (sourceCommit != null &&
        (sourceCommit is! String || !_commitPattern.hasMatch(sourceCommit))) {
      problems.add('$name: sourceCommit must be 40 lowercase hex digits');
    }
    final license = entry['license'];
    if (license is! String || license.isEmpty) {
      problems.add('$name: license must name the grammar\'s licence');
    }
    final generate = entry['generate'];
    if (generate != null && generate is! bool) {
      problems.add('$name: generate must be a boolean');
    }
    final extraNotices = entry['extraNotices'];
    if (extraNotices != null &&
        (extraNotices is! List ||
            extraNotices.any((path) => path is! String || path.isEmpty))) {
      problems.add('$name: extraNotices must be a list of paths');
    }
  }
  return problems;
}

/// Thrown when a checkout cannot supply a pin.
final class PinException implements Exception {
  const PinException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Reads the pin for the grammar [url] from its checkout at [directory]:
/// the checkout's `HEAD` commit.
///
/// Throws a [PinException] when the checkout's origin is not [url], or when
/// no branch of origin contains `HEAD`, so a pin never names a local commit
/// or one only a fork carries.
Future<String> pinFromCheckout(
  GitRunner git,
  String directory,
  String url,
) async {
  final origin = (await git(directory, ['remote', 'get-url', 'origin'])).trim();
  if (normalizeRepositoryUrl(origin) != normalizeRepositoryUrl(url)) {
    throw PinException(
      '${repositoryName(url)}: origin is $origin, '
      'grammars.json says $url',
    );
  }
  final head = (await git(directory, ['rev-parse', 'HEAD'])).trim();
  await requireOnOrigin(git, directory, head, repositoryName(url));
  return head;
}

/// Throws a [PinException] unless one of `origin`'s remote-tracking
/// branches in [directory] contains [commit]; another remote's branch does
/// not count.
Future<void> requireOnOrigin(
  GitRunner git,
  String directory,
  String commit,
  String name,
) async {
  final branches = await git(directory, [
    'branch',
    '-r',
    '--contains',
    commit,
    '--list',
    'origin/*',
  ]);
  if (branches.trim().isEmpty) {
    throw PinException('$name: no branch on origin contains $commit');
  }
}

/// Returns [entry] pinned at [commit], replacing any earlier pin.
///
/// A [sourceCommit] is recorded when given; otherwise any earlier
/// `sourceCommit` is dropped, because it described the earlier pin.
Map<String, Object?> withPin(
  Map<String, Object?> entry,
  String commit, {
  String? sourceCommit,
}) {
  if (!_commitPattern.hasMatch(commit)) {
    throw PinException('$commit is not a 40-hex commit');
  }
  if (sourceCommit != null && !_commitPattern.hasMatch(sourceCommit)) {
    throw PinException('$sourceCommit is not a 40-hex commit');
  }
  final pinned = {...entry, 'commit': commit}..remove('sourceCommit');
  if (sourceCommit != null) pinned['sourceCommit'] = sourceCommit;
  return pinned;
}
