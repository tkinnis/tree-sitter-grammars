/// Pins every grammar in `tool/grammars.json` to one upstream commit.
///
/// Usage:
///
/// ```sh
/// dart run tool/pin_grammars.dart --from-checkouts
/// dart run tool/pin_grammars.dart --set tree-sitter-perl=<sha> \
///     [--source-commit=<sha>]
/// dart run tool/pin_grammars.dart --record-files
/// dart run tool/pin_grammars.dart --check
/// ```
///
/// Every pin records, beside its commit, the `filesSha256` of the files
/// its tree holds (see `src/files_digest.dart`), read from the object
/// store; the build checks every tree it compiles against it.
///
/// `--from-checkouts` pins each grammar at its `grammars/<repo>` checkout's
/// `HEAD`. It refuses the whole run, writing nothing, if any checkout's
/// origin differs from the entry's `url` or if no branch on origin contains
/// its `HEAD`.
///
/// `--set` pins one grammar. It fetches the grammar's origin and refuses a
/// commit (or `--source-commit`) that no branch on origin contains.
///
/// `--record-files` records `filesSha256` afresh for every grammar at its
/// pin and for the runtime at `tool/toolchain.json`'s commit, from their
/// object stores, changing no commit.
///
/// `--check` exits 1 unless every entry with a `url` has a 40-hex `commit`,
/// a 64-hex `filesSha256` and a `license`, and its optional pin fields are
/// well formed.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'src/files_digest.dart';
import 'src/git.dart';
import 'src/grammar_pins.dart';
import 'src/grammar_sources.dart';

Future<void> main(List<String> args) async {
  final root = p.dirname(p.dirname(p.fromUri(Platform.script)));
  final grammarsFile = File(p.join(root, 'tool', 'grammars.json'));
  final entries = parseGrammars(grammarsFile.readAsStringSync());
  try {
    switch (args) {
      case ['--check']:
        _check(entries);
      case ['--from-checkouts']:
        final pinned = await _fromCheckouts(root, entries);
        grammarsFile.writeAsStringSync(encodeGrammars(pinned));
        _check(pinned);
      case ['--record-files']:
        final pinned = await _recordFiles(root, entries);
        grammarsFile.writeAsStringSync(encodeGrammars(pinned));
        _check(pinned);
      case ['--set', final assignment, ...final rest]
          when rest.length <= 1 &&
              rest.every((arg) => arg.startsWith('--source-commit=')):
        final sourceCommit = rest.isEmpty
            ? null
            : rest.single.substring('--source-commit='.length);
        final pinned = await _set(root, entries, assignment, sourceCommit);
        grammarsFile.writeAsStringSync(encodeGrammars(pinned));
        _check(pinned);
      default:
        stderr.writeln(
          'usage: dart run tool/pin_grammars.dart '
          '--from-checkouts | --set <repo>=<sha> [--source-commit=<sha>] '
          '| --record-files | --check',
        );
        exitCode = 64;
    }
  } on PinException catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}

void _check(List<Map<String, Object?>> entries) {
  final problems = pinProblems(entries);
  for (final problem in problems) {
    stderr.writeln('grammars.json: $problem');
  }
  final pinned = entries.where((entry) => entry['url'] != null).length;
  print('$pinned grammar repositories, ${problems.length} pin problems');
  if (problems.isNotEmpty) exitCode = 1;
}

Future<List<Map<String, Object?>>> _fromCheckouts(
  String root,
  List<Map<String, Object?>> entries,
) async {
  final refusals = <String>[];
  final pinned = <Map<String, Object?>>[];
  for (final entry in entries) {
    final url = entry['url'];
    if (url is! String) {
      pinned.add(entry);
      continue;
    }
    final directory = p.join(root, 'grammars', repositoryName(url));
    try {
      if (!Directory(p.join(directory, '.git')).existsSync()) {
        throw PinException('${repositoryName(url)}: no checkout at $directory');
      }
      final commit = await pinFromCheckout(runGit, directory, url);
      pinned.add(
        withPin(
          entry,
          commit,
          filesSha256: await filesDigest(
            await committedFiles(directory, commit),
          ),
        ),
      );
    } on PinException catch (error) {
      refusals.add(error.message);
    } on GitException catch (error) {
      refusals.add('${repositoryName(url)}: $error');
    } on FilesDigestException catch (error) {
      refusals.add('${repositoryName(url)}: $error');
    }
  }
  if (refusals.isNotEmpty) {
    throw PinException(
      ['grammars.json left unchanged:', ...refusals].join('\n  '),
    );
  }
  return pinned;
}

Future<List<Map<String, Object?>>> _set(
  String root,
  List<Map<String, Object?>> entries,
  String assignment,
  String? sourceCommit,
) async {
  final (name, commit) = switch (assignment.split('=')) {
    [final name, final commit] => (name, commit),
    _ => throw PinException('--set takes <repo>=<sha>, not $assignment'),
  };
  final index = entries.indexWhere(
    (entry) =>
        entry['url'] is String &&
        repositoryName(entry['url']! as String) == name,
  );
  if (index < 0) {
    throw PinException('$name: no such repository in grammars.json');
  }
  final url = entries[index]['url']! as String;
  final directory = p.join(root, 'grammars', name);
  final Map<String, Object?> pinned;
  try {
    await ensureObjectStore(runGit, directory, url);
    final shallow =
        (await runGit(directory, [
          'rev-parse',
          '--is-shallow-repository',
        ])).trim() ==
        'true';
    await runGit(directory, [
      'fetch',
      '--quiet',
      if (shallow) '--unshallow',
      'origin',
    ]);
    await requireOnOrigin(runGit, directory, commit, name);
    if (sourceCommit != null) {
      await requireOnOrigin(runGit, directory, sourceCommit, name);
    }
    pinned = withPin(
      entries[index],
      commit,
      filesSha256: await filesDigest(await committedFiles(directory, commit)),
      sourceCommit: sourceCommit,
    );
  } on GitException catch (error) {
    throw PinException('$name: $error');
  } on GrammarSourceException catch (error) {
    throw PinException(error.message);
  } on FilesDigestException catch (error) {
    throw PinException('$name: $error');
  }
  return [...entries]..[index] = pinned;
}

/// [entries] with each grammar's `filesSha256` read afresh from its object
/// store at its pin, after writing the runtime's into `tool/toolchain.json`.
///
/// A store that lacks its pinned commit fetches exactly that commit. Throws
/// a [PinException] listing every repository that could not be read,
/// writing nothing.
Future<List<Map<String, Object?>>> _recordFiles(
  String root,
  List<Map<String, Object?>> entries,
) async {
  final refusals = <String>[];
  Future<String?> digest(String name, String store, String commit) async {
    try {
      return await filesDigest(await committedFiles(store, commit));
    } on Exception catch (error) {
      refusals.add('$name: $error');
      return null;
    }
  }

  // Read as JSON, not as a Toolchain, which requires the digest this
  // records.
  final toolchainFile = File(p.join(root, 'tool', 'toolchain.json'));
  final json = jsonDecode(toolchainFile.readAsStringSync()) as Map;
  final treeSitter = json['treeSitter'] as Map;
  final runtime = await digest(
    'tree-sitter',
    p.join(root, 'tree-sitter'),
    treeSitter['commit'] as String,
  );
  final pinned = <Map<String, Object?>>[];
  for (final entry in entries) {
    if (entry case {'url': final String url, 'commit': final String commit}) {
      final name = repositoryName(url);
      final store = p.join(root, 'grammars', name);
      try {
        await ensureObjectStore(runGit, store, url);
        await ensureCommit(runGit, store, commit, name);
      } on Exception catch (error) {
        refusals.add('$name: $error');
        continue;
      }
      if (await digest(name, store, commit) case final files?) {
        pinned.add(
          withPin(
            entry,
            commit,
            filesSha256: files,
            sourceCommit: entry['sourceCommit'] as String?,
          ),
        );
      }
    } else {
      pinned.add(entry);
    }
  }
  if (refusals.isNotEmpty) {
    throw PinException(
      [
        'grammars.json and toolchain.json left unchanged:',
        ...refusals,
      ].join('\n  '),
    );
  }
  json['treeSitter'] = {
    for (final MapEntry(:key, :value) in treeSitter.entries)
      if (key != 'filesSha256') ...{
        key: value,
        if (key == 'commit') 'filesSha256': runtime,
      },
  };
  toolchainFile.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(json)}\n',
  );
  print('tree-sitter: filesSha256 $runtime');
  return pinned;
}
