/// Writes `output/manifest.json` and each language's query bundle.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'grammar_plan.dart';

/// The query kinds a manifest entry reports as present or absent.
const queryKinds = [
  'highlights',
  'injections',
  'locals',
  'tags',
  'folds',
  'indents',
  'textobjects',
];

const _encoder = JsonEncoder.withIndent('  ');

/// Thrown when a language's query files cannot be bundled.
final class ManifestException implements Exception {
  const ManifestException(this.message);

  final String message;

  @override
  String toString() => message;
}

String _capitalize(String text) =>
    text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

/// Which of [queryKinds] `queries/<name>/` under [root] holds.
Map<String, bool> queryAvailability(String root, String name) => {
      for (final kind in queryKinds)
        kind: File(p.join(root, 'queries', name, '$kind.scm')).existsSync(),
    };

/// The manifest entry of a compiled grammar.
///
/// [abi] is the `LANGUAGE_VERSION` of the `parser.c` the dylib was built
/// from.
Map<String, Object?> grammarEntry(String root, GrammarBuild build, int abi) {
  final entry = build.entry;
  final metadata = build.metadata;
  final fileTypes =
      (entry['file-types'] ?? metadata['file-types'] ?? [build.name]) as List;
  final filenames = entry['filenames'] as List?;
  return {
    'displayName': entry['displayName'] ??
        metadata['camelcase'] ??
        metadata['camel-case-name'] ??
        _capitalize(build.name),
    'symbol': build.symbol,
    'scope': entry['scope'] ?? metadata['scope'] ?? 'source.${build.name}',
    'extensions': [for (final type in fileTypes) '.$type'],
    'dylib_dir': build.dylibDirectory,
    'queries_dir': 'queries/${build.name}',
    'queries': queryAvailability(root, build.name),
    if (filenames != null && filenames.isNotEmpty) 'filenames': filenames,
    'source': {
      'url': build.url,
      'commit': build.commit,
      if (build.sourceCommit case final sourceCommit?)
        'sourceCommit': sourceCommit,
      'path': build.path,
      'parser': build.generate ? 'generated' : 'committed',
      'abi': abi,
      'license': build.license,
    },
  };
}

/// The manifest entry of a language with no parser, such as plain text.
Map<String, Object?> noopEntry(Map<String, Object?> entry) {
  final name = entry['name']! as String;
  return {
    'displayName': entry['displayName'] ?? name,
    'scope': entry['scope'] ?? 'text.$name',
    'extensions': entry['extensions'] ?? const <String>[],
  };
}

/// The manifest entry of a query-only language, which other languages'
/// queries inherit.
Map<String, Object?> queryOnlyEntry(Map<String, Object?> entry) {
  final name = entry['name']! as String;
  return {
    'displayName': entry['displayName'] ?? _capitalize(name),
    'scope': entry['scope'] ?? 'source.$name',
    'extensions': entry['extensions'] ?? const <String>[],
    'queryOnly': true,
    'queries_dir': 'queries/$name',
    'queries': entry['queries'] ??
        {for (final kind in queryKinds) kind: kind == 'highlights'},
  };
}

/// Copies `queries/<name>/*.scm` under [root] into [destination], with a
/// `config.json` that adds [queries] to the language's own.
///
/// Throws a [ManifestException] when the language has no query directory
/// or no `config.json`.
void bundleQueries(
  String root,
  String name,
  Map<String, Object?> queries,
  String destination,
) {
  final source = Directory(p.join(root, 'queries', name));
  final config = File(p.join(source.path, 'config.json'));
  if (!config.existsSync()) {
    throw ManifestException('$name: no queries/$name/config.json');
  }
  Directory(destination).createSync(recursive: true);
  final queryFiles = source
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.scm'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in queryFiles) {
    file.copySync(p.join(destination, p.basename(file.path)));
  }
  final json = jsonDecode(config.readAsStringSync()) as Map<String, Object?>;
  File(p.join(destination, 'config.json'))
      .writeAsStringSync(_encoder.convert({...json, 'queries': queries}));
}

/// Encodes [manifest] as `output/manifest.json` is written.
String encodeManifest(Map<String, Map<String, Object?>> manifest) =>
    _encoder.convert(manifest);
