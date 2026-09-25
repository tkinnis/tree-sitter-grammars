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
/// `--from-checkouts` moves each grammar's pin forward to its
/// `grammars/<repo>` checkout's `HEAD`, when that `HEAD` contains the pin,
/// recording `filesSha256` and, for a generated grammar, `generatedSha256`
/// afresh. It keeps, and names with the `--set` that moves it, a pin that
/// `HEAD` does not contain (one chosen ahead of the checkout or on another
/// line of history) and a pin on a deploy branch, whose checkout names the
/// source commit rather than the deploy commit. It refuses the whole run,
/// writing nothing, if any checkout's origin differs from the entry's
/// `url` or if no branch on origin contains its `HEAD`.
///
/// `--set` pins one grammar. It fetches the grammar's origin and refuses a
/// commit (or `--source-commit`) that no branch on origin contains. A pin
/// on a deploy branch takes the commit it was deployed from as
/// `--source-commit`.
///
/// `--record-files` records `filesSha256` afresh for every grammar at its
/// pin and for the runtime at `tool/toolchain.json`'s commit, from their
/// object stores, changing no commit.
///
/// `--check` exits 1 unless every entry with a `url` has a 40-hex `commit`,
/// a 64-hex `filesSha256` and a `license`, and its optional pin fields are
/// well formed. Every other mode writes only a result that passes the same
/// check, and writes nothing otherwise.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'src/files_digest.dart';
import 'src/git.dart';
import 'src/grammar_pins.dart';
import 'src/generated_sources.dart';
import 'src/grammar_plan.dart';
import 'src/grammar_sources.dart';
import 'src/toolchain.dart';
import 'src/tree_sitter_cli.dart';

Future<void> main(List<String> args) async {
  final root = p.dirname(p.dirname(p.fromUri(Platform.script)));
  final grammarsFile = File(p.join(root, 'tool', 'grammars.json'));
  final entries = parseGrammars(grammarsFile.readAsStringSync());
  try {
    switch (args) {
      case ['--check']:
        _check(entries);
      case ['--from-checkouts']:
        _write(grammarsFile, await _fromCheckouts(root, entries));
      case ['--record-files']:
        final (:pinned, :toolchain, :runtime) = await _recordFiles(
          root,
          entries,
        );
        _write(grammarsFile, pinned);
        File(
          p.join(root, 'tool', 'toolchain.json'),
        ).writeAsStringSync(toolchain);
        print('tree-sitter: filesSha256 $runtime');
      case ['--set', final assignment, ...final rest]
          when rest.length <= 1 &&
              rest.every((arg) => arg.startsWith('--source-commit=')):
        final sourceCommit = rest.isEmpty
            ? null
            : rest.single.substring('--source-commit='.length);
        _write(
          grammarsFile,
          await _set(root, entries, assignment, sourceCommit),
        );
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

/// Writes [pinned] to [file] when it passes every pin check, and throws a
/// [PinException] listing the problems, writing nothing, when it does not.
void _write(File file, List<Map<String, Object?>> pinned) {
  final problems = pinProblems(pinned);
  if (problems.isNotEmpty) {
    throw PinException(
      ['grammars.json left unchanged:', ...problems].join('\n  '),
    );
  }
  file.writeAsStringSync(encodeGrammars(pinned));
  _check(pinned);
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
  final moved = <String>[];
  final kept = <String>[];
  for (final entry in entries) {
    final url = entry['url'];
    if (url is! String) {
      pinned.add(entry);
      continue;
    }
    final name = repositoryName(url);
    final directory = p.join(root, 'grammars', name);
    try {
      if (!Directory(p.join(directory, '.git')).existsSync()) {
        throw PinException('$name: no checkout at $directory');
      }
      final (:moveTo, kept: reason) = await checkoutMove(
        runGit,
        directory,
        entry,
      );
      if (reason != null) kept.add(reason);
      if (moveTo == null) {
        pinned.add(entry);
        continue;
      }
      pinned.add(
        withPin(
          entry,
          moveTo,
          filesSha256: await filesDigest(
            await committedFiles(directory, moveTo),
          ),
          generatedSha256: entry['generate'] == true
              ? await _generatedDigest(
                  root,
                  Toolchain.load(root),
                  entry,
                  directory,
                  moveTo,
                )
              : null,
        ),
      );
      moved.add('$name: ${entry['commit']} -> $moveTo');
    } on PinException catch (error) {
      refusals.add(error.message);
    } on GitException catch (error) {
      refusals.add('$name: $error');
    } on Exception catch (error) {
      refusals.add('$name: $error');
    }
  }
  if (refusals.isNotEmpty) {
    throw PinException(
      ['grammars.json left unchanged:', ...refusals].join('\n  '),
    );
  }
  print('${moved.length} pins moved forward, ${kept.length} kept');
  for (final line in [...moved, ...kept]) {
    print('  $line');
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
      generatedSha256: entries[index]['generate'] == true
          ? await _generatedDigest(
              root,
              Toolchain.load(root),
              entries[index],
              directory,
              commit,
            )
          : null,
    );
  } on GitException catch (error) {
    throw PinException('$name: $error');
  } on GrammarSourceException catch (error) {
    throw PinException(error.message);
  } on PinException {
    rethrow;
  } on Exception catch (error) {
    throw PinException('$name: $error');
  }
  return [...entries]..[index] = pinned;
}

/// [entries] with each grammar's `filesSha256`, and a generated grammar's
/// `generatedSha256`, read afresh at its pin, with the text of
/// `tool/toolchain.json` recording the runtime's `filesSha256`, and that
/// digest.
///
/// A store that lacks its pinned commit fetches exactly that commit. Throws
/// a [PinException] listing every repository that could not be read. It
/// writes nothing.
Future<({List<Map<String, Object?>> pinned, String toolchain, String runtime})>
_recordFiles(String root, List<Map<String, Object?>> entries) async {
  final refusals = <String>[];
  // Read as JSON, not as a Toolchain, which requires the digest this
  // records.
  final toolchainFile = File(p.join(root, 'tool', 'toolchain.json'));
  final json = jsonDecode(toolchainFile.readAsStringSync()) as Map;
  final treeSitter = json['treeSitter'] as Map;
  final String runtime;
  try {
    runtime = await filesDigest(
      await committedFiles(
        p.join(root, 'tree-sitter'),
        treeSitter['commit'] as String,
      ),
    );
  } on Exception catch (error) {
    throw PinException('tree-sitter: $error');
  }
  json['treeSitter'] = {
    for (final MapEntry(:key, :value) in treeSitter.entries)
      if (key != 'filesSha256') ...{
        key: value,
        if (key == 'commit') 'filesSha256': runtime,
      },
  };
  final toolchain = Toolchain.parse(jsonEncode(json));
  final pinned = <Map<String, Object?>>[];
  for (final entry in entries) {
    if (entry case {'url': final String url, 'commit': final String commit}) {
      final name = repositoryName(url);
      final store = p.join(root, 'grammars', name);
      try {
        await ensureObjectStore(runGit, store, url);
        await ensureCommit(runGit, store, commit, name);
        pinned.add(
          withPin(
            entry,
            commit,
            filesSha256: await filesDigest(await committedFiles(store, commit)),
            sourceCommit: entry['sourceCommit'] as String?,
            generatedSha256: entry['generate'] == true
                ? await _generatedDigest(root, toolchain, entry, store, commit)
                : null,
          ),
        );
      } on Exception catch (error) {
        refusals.add('$name: $error');
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
  return (
    pinned: pinned,
    toolchain: '${const JsonEncoder.withIndent('  ').convert(json)}\n',
    runtime: runtime,
  );
}

/// The digest of what the pinned CLI of [toolchain] generates for the
/// generated grammar [entry] at [commit], extracted from its object store
/// [store], at the language ABI of the runtime `toolchain.json` pins.
Future<String> _generatedDigest(
  String root,
  Toolchain toolchain,
  Map<String, Object?> entry,
  String store,
  String commit,
) async {
  final api = await runGit(p.join(root, 'tree-sitter'), [
    'show',
    '${toolchain.treeSitterCommit}:lib/include/tree_sitter/api.h',
  ]);
  final scratch = Directory.systemTemp.createTempSync('pin_generate');
  try {
    final sourceRoot = p.join(scratch.path, 'src');
    await extractCommit(
      store,
      commit,
      p.join(sourceRoot, repositoryName(entry['url']! as String)),
    );
    final builds = planGrammars(root, [entry], sourceRoot: sourceRoot);
    if (builds.length != 1) {
      throw PinException(
        'a generated entry builds one grammar, not '
        '${builds.map((b) => b.name).join(', ')}',
      );
    }
    final digest = await generatedDigest(
      root: root,
      toolchain: toolchain,
      build: builds.single,
      sourceRoot: sourceRoot,
      abi: apiLanguageVersions(api).current,
      scratch: p.join(scratch.path, 'gen'),
    );
    print('${builds.single.name}: generatedSha256 $digest');
    return digest;
  } finally {
    scratch.deleteSync(recursive: true);
  }
}
