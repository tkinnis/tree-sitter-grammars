/// Applies the patches `tool/grammars.json` lists for a grammar repository
/// to its tree extracted at the pin, before anything compiles it.
///
/// A patch is this repository's own file, `patches/<repository>/<name>.patch`,
/// in the format `git diff` writes, with paths relative to the grammar
/// repository's root. Text before its first `diff --git` line says what it
/// changes and why. An entry lists its patches under `patches`, in the order
/// they apply, and records under `patchedSha256` the digest of the tree they
/// leave, as `files_digest.dart` computes it, so a patched tree is held to a
/// committed value exactly as an unpatched one is held to `filesSha256`.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import 'files_digest.dart';
import 'git.dart';
import 'source_bundles.dart';

/// The directory of this repository holding the patches.
const patchesDirectoryName = 'patches';

final _digestPattern = RegExp(r'^[0-9a-f]{64}$');

/// Thrown when a patch cannot be read or applied, or leaves a tree other
/// than the one its entry records.
final class SourcePatchException implements Exception {
  const SourcePatchException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The patches [entry] lists, in the order they apply; empty when it lists
/// none.
List<String> entryPatches(Map<String, Object?> entry) => [
  for (final patch in entry['patches'] as List? ?? const []) patch as String,
];

/// Every problem with the `patches` and `patchedSha256` of the entry of the
/// repository [name]; empty when it has neither, or a list of distinct
/// paths `patches/<name>/<file>.patch` and a 64-hex digest of the tree they
/// leave.
List<String> patchFieldProblems(String name, Map<String, Object?> entry) {
  final patches = entry['patches'];
  final patched = entry['patchedSha256'];
  if (patches == null) {
    return [
      if (patched != null)
        '$name: patchedSha256 belongs only to an entry that lists patches',
    ];
  }
  final pattern = RegExp(
    '^$patchesDirectoryName/${RegExp.escape(name)}/[^/]+\\.patch\$',
  );
  return [
    if (patches is! List ||
        patches.isEmpty ||
        patches.any((path) => path is! String || !pattern.hasMatch(path)))
      '$name: patches must be a list of paths '
          '$patchesDirectoryName/$name/<name>.patch'
    else if (patches.toSet().length != patches.length)
      '$name: patches lists one patch twice',
    if (patched is! String || !_digestPattern.hasMatch(patched))
      '$name: an entry with patches records the patchedSha256 of the tree '
          'they leave, 64 lowercase hex digits',
  ];
}

/// The path of every file [patch], a patch's text, changes, relative to the
/// patched tree's root, in the order its `diff --git` lines name them.
List<String> patchedPaths(String patch) => [
  for (final match in RegExp(
    r'^diff --git a/(\S+) b/(\S+)$',
    multiLine: true,
  ).allMatches(patch))
    match.group(2)!,
];

/// Applies [patches], each a path under [patchRoot], to the tree at
/// [directory], in order.
///
/// Each runs through [bundleGit]'s `git apply`, cut off from every
/// configuration outside the tree and from the repository [directory] may
/// lie inside, so its paths resolve against [directory] alone and a path
/// leading out of it is refused. A patch that does not apply exactly, its
/// context included, throws a [SourcePatchException] naming it.
Future<void> applyPatches(
  String patchRoot,
  List<String> patches,
  String directory,
) async {
  final ceiling = p.dirname(p.absolute(directory));
  for (final patch in patches) {
    final file = File(p.join(patchRoot, patch));
    if (!file.existsSync()) {
      throw SourcePatchException('$patch does not exist');
    }
    if (patchedPaths(file.readAsStringSync()).isEmpty) {
      throw SourcePatchException('$patch changes no file');
    }
    try {
      await runIsolatedGit(
        directory,
        ['apply', '--whitespace=nowarn', p.absolute(file.path)],
        environment: {
          ...Platform.environment,
          'GIT_CEILING_DIRECTORIES': ceiling,
        },
        executable: bundleGit,
      );
    } on GitException catch (error) {
      throw SourcePatchException(
        '$patch does not apply: ${error.stderr.trim()}',
      );
    }
  }
}

/// Applies [source]'s patches, read from under [patchRoot], to its tree at
/// [directory], and requires the tree they leave to have the
/// `patchedSha256` its entry records; does nothing for a source with no
/// patches.
///
/// Throws a [SourcePatchException] when a patch does not apply or the
/// patched tree has another digest.
Future<void> patchSource(
  PinnedSource source,
  String patchRoot,
  String directory,
) async {
  if (source.patches.isEmpty) return;
  await applyPatches(patchRoot, source.patches, directory);
  final digest = await filesDigest(await unpackedFiles(directory));
  if (digest != source.patchedSha256) {
    throw SourcePatchException(
      'its patched files have patchedSha256 $digest; the pin records '
      '${source.patchedSha256}; if the patches are right, record the digest '
      'with dart run tool/pin_grammars.dart --record-files',
    );
  }
}

/// What `build_info.json` records of [source]'s patches beside its bundle:
/// each patch's path and sha256, in the order they apply, and the
/// `patchedSha256` of the tree they leave. Empty for a source with no
/// patches.
Future<Map<String, Object?>> patchRecord(
  PinnedSource source,
  String patchRoot,
) async => source.patches.isEmpty
    ? const {}
    : {
        'patches': [
          for (final patch in source.patches)
            {
              'file': patch,
              'sha256': await fileSha256(p.join(patchRoot, patch)),
            },
        ],
        'patchedSha256': source.patchedSha256,
      };

/// Every way [record], what `build_info.json` records of [source]'s
/// bundle, differs from the [patchRecord] the patches under [patchRoot]
/// make: a patch missing, added, reordered or of another sha256, or
/// another `patchedSha256`.
Future<List<String>> patchRecordProblems(
  PinnedSource source,
  Map<String, Object?> record,
  String patchRoot,
) async {
  final expected = await patchRecord(source, patchRoot);
  String describe(Object? patches) => patches is List
      ? patches
            .map((patch) => patch is Map ? '${patch['file']}' : '$patch')
            .join(', ')
      : 'none';
  final problems = <String>[];
  final recorded = record['patches'];
  final wanted = expected['patches'] as List?;
  if (describe(recorded) != describe(wanted)) {
    problems.add(
      'build_info.json records the patches ${describe(recorded)}; '
      'grammars.json lists ${describe(wanted)}',
    );
  } else if (wanted != null) {
    for (final (index, patch) in wanted.indexed) {
      final sha256 = ((recorded! as List)[index] as Map)['sha256'];
      if (sha256 != (patch as Map)['sha256']) {
        problems.add(
          'build_info.json records ${patch['file']} at sha256 $sha256; the '
          'committed patch has ${patch['sha256']}',
        );
      }
    }
  }
  if (record['patchedSha256'] != expected['patchedSha256']) {
    problems.add(
      'build_info.json records patchedSha256 ${record['patchedSha256']}; '
      'grammars.json records ${expected['patchedSha256']}',
    );
  }
  return problems;
}
