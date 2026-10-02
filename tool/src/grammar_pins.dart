/// Reads, checks and rewrites the pins in `tool/grammars.json`.
///
/// Every entry with a `url` builds a grammar and carries:
///
/// - `commit`: the 40-hex upstream commit the build extracts.
/// - `filesSha256`: the digest of the files `commit`'s tree holds, as
///   `files_digest.dart` computes it, which every supplied tree is checked
///   against, whether it comes from the object store or a release's source
///   bundle.
/// - `sourceCommit` (optional): the commit on the upstream's source branch
///   that `commit` was deployed from, for a pin on a deploy branch.
/// - `license`: the SPDX identifier of the grammar's licence.
/// - `generate` (optional): true when the grammar commits no `src/parser.c`
///   and the build generates it from `src/grammar.json`.
/// - `generatedSha256` (with `generate`): the digest, as `files_digest.dart`
///   computes it, of the files the pinned CLI generates for the pin at the
///   runtime's language ABI, which the generated sources are checked
///   against whether generated or taken from a release's bundle.
/// - `patches` (optional): this repository's patches to the tree at
///   `commit`, each `patches/<repository>/<name>.patch`, applied in order
///   before anything compiles it (see `source_patches.dart`).
/// - `patchedSha256` (with `patches`): the digest, as `files_digest.dart`
///   computes it, of the files the tree holds once they are applied, which
///   every patched tree is checked against.
/// - `extraNotices` (optional): compiled source files carrying a licence
///   comment of their own, beyond the grammar's licence file, which the
///   notices reproduce.
library;

import 'dart:convert';

import 'git.dart';
import 'source_patches.dart';

final _commitPattern = RegExp(r'^[0-9a-f]{40}$');
final _digestPattern = RegExp(r'^[0-9a-f]{64}$');

/// The pin fields, in the order they follow `url` in each entry.
const pinFields = [
  'commit',
  'filesSha256',
  'sourceCommit',
  'license',
  'generate',
  'generatedSha256',
  'patches',
  'patchedSha256',
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
    final filesSha256 = entry['filesSha256'];
    if (filesSha256 is! String || !_digestPattern.hasMatch(filesSha256)) {
      problems.add('$name: filesSha256 must be 64 lowercase hex digits');
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
    final generated = entry['generatedSha256'];
    if (generate == true &&
        (generated is! String || !_digestPattern.hasMatch(generated))) {
      problems.add(
        '$name: a generated grammar\'s generatedSha256 must be 64 lowercase '
        'hex digits',
      );
    } else if (generate != true && generated != null) {
      problems.add(
        '$name: generatedSha256 belongs only to a generated grammar',
      );
    }
    problems.addAll(patchFieldProblems(name, entry));
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

/// What `--from-checkouts` makes of one entry: the commit it moves the pin
/// to, or why it keeps the pin; both null when the pin is already the
/// checkout's `HEAD`.
typedef CheckoutMove = ({String? moveTo, String? kept});

/// Decides whether the grammar [entry] moves to the `HEAD` of its checkout
/// at [directory].
///
/// A pin moves only forward, to a `HEAD` that contains it, so a pin chosen
/// ahead of the checkout, or on another line of history, is kept. A pin on
/// a deploy branch, which records a `sourceCommit`, is kept too: a checkout
/// names its source commit, never the deploy commit the pin needs. Each
/// kept pin comes with the reason and the `--set` that moves it.
///
/// Throws a [PinException] as [pinFromCheckout] does, and when git cannot
/// tell whether `HEAD` contains the pin, for example because the store
/// lacks it.
Future<CheckoutMove> checkoutMove(
  GitRunner git,
  String directory,
  Map<String, Object?> entry,
) async {
  final url = entry['url']! as String;
  final name = repositoryName(url);
  final pin = entry['commit'];
  if (entry['sourceCommit'] case final String source) {
    return (
      moveTo: null,
      kept:
          '$name: kept at its deploy pin $pin, deployed from $source; move '
          'it with --set $name=<deploy commit> --source-commit=<source '
          'commit>',
    );
  }
  final head = await pinFromCheckout(git, directory, url);
  if (head == pin) return (moveTo: null, kept: null);
  if (pin is! String) return (moveTo: head, kept: null);
  try {
    await git(directory, ['merge-base', '--is-ancestor', pin, head]);
  } on GitException catch (error) {
    if (error.exitCode != 1) {
      throw PinException(
        '$name: cannot tell whether HEAD $head contains the pin $pin: '
        '${error.stderr.trim()}',
      );
    }
    return (
      moveTo: null,
      kept:
          '$name: kept at $pin, which its checkout\'s HEAD $head does not '
          'contain; move it with --set $name=<sha>',
    );
  }
  return (moveTo: head, kept: null);
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

/// Returns [entry] pinned at [commit], whose files have the digest
/// [filesSha256], replacing any earlier pin.
///
/// A [sourceCommit], a [generatedSha256] and a [patchedSha256] are recorded
/// when given; otherwise any earlier one is dropped, because it described
/// the earlier pin. The entry's `patches` are kept: they are this
/// repository's, and an entry that lists them without a [patchedSha256]
/// fails [pinProblems].
Map<String, Object?> withPin(
  Map<String, Object?> entry,
  String commit, {
  required String filesSha256,
  String? sourceCommit,
  String? generatedSha256,
  String? patchedSha256,
}) {
  if (!_commitPattern.hasMatch(commit)) {
    throw PinException('$commit is not a 40-hex commit');
  }
  if (!_digestPattern.hasMatch(filesSha256)) {
    throw PinException('$filesSha256 is not a 64-hex digest');
  }
  if (sourceCommit != null && !_commitPattern.hasMatch(sourceCommit)) {
    throw PinException('$sourceCommit is not a 40-hex commit');
  }
  if (patchedSha256 != null && !_digestPattern.hasMatch(patchedSha256)) {
    throw PinException('$patchedSha256 is not a 64-hex digest');
  }
  final pinned = {...entry, 'commit': commit, 'filesSha256': filesSha256}
    ..remove('sourceCommit')
    ..remove('generatedSha256')
    ..remove('patchedSha256');
  if (sourceCommit != null) pinned['sourceCommit'] = sourceCommit;
  if (generatedSha256 != null) pinned['generatedSha256'] = generatedSha256;
  if (patchedSha256 != null) pinned['patchedSha256'] = patchedSha256;
  return pinned;
}
