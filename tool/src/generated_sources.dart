/// The sources the pinned tree-sitter CLI generates for a grammar that
/// commits no `parser.c`: held to the digest its pin records, and packed
/// into a bundle a release attaches, so a rebuild from the release's assets
/// runs no CLI.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import 'files_digest.dart';
import 'grammar_plan.dart';
import 'release_archive.dart';
import 'source_bundles.dart';
import 'toolchain.dart';
import 'tree_sitter_cli.dart';

/// Thrown when generated sources are not the ones their pin records, or
/// cannot be supplied.
final class GeneratedSourcesException implements Exception {
  const GeneratedSourcesException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The file name of the bundle holding what the CLI generates for the
/// grammar [name] at [commit].
String generatedBundleName(String name, String commit) =>
    '$name-generated-$commit.tar.gz';

/// The `generatedSha256` [build]'s entry records.
String? recordedGeneratedDigest(GrammarBuild build) =>
    build.entry['generatedSha256'] as String?;

/// Requires the files under [directory], generated for [build], to have
/// the `generatedSha256` its entry records; [hint] ends the message of the
/// [GeneratedSourcesException] thrown otherwise.
Future<void> requireGenerated(
  GrammarBuild build,
  String directory,
  String hint,
) async {
  final files = await unpackedFiles(directory);
  final digest = await filesDigest(files);
  final recorded = recordedGeneratedDigest(build);
  if (digest != recorded) {
    throw GeneratedSourcesException(
      '${build.name}: its ${files.length} generated files have '
      'generatedSha256 $digest; grammars.json records $recorded; $hint',
    );
  }
}

/// Packs every file under [directory] into [bundle], under a top-level
/// directory of [directory]'s name, as the release archive is packed: in
/// sorted order, with mode 0644 (0755 for a directory), the time 0 and
/// no owner but root, so the same files always pack to the same bytes.
Future<void> packGenerated(String directory, String bundle) async {
  final parent = p.dirname(directory);
  final name = p.basename(directory);
  final files = [
    for (final entity in Directory(
      directory,
    ).listSync(recursive: true, followLinks: false))
      if (entity is File)
        p.posix.joinAll([
          name,
          ...p.split(p.relative(entity.path, from: directory)),
        ]),
  ]..sort();
  File(bundle).parent.createSync(recursive: true);
  await normalizeArchiveFiles(parent, files, 0);
  await packArchive(parent, files, bundle);
}

/// The `build_info.json` record of [build]'s generated bundle [file],
/// relative to `output/`, whose sha256 is [sha256].
Map<String, Object?> generatedRecord(
  GrammarBuild build,
  Toolchain toolchain,
  String file,
  String sha256,
) => {
  'url': build.entry['url'],
  'commit': build.entry['commit'],
  'cli': toolchain.cliVersion,
  'file': file,
  'sha256': sha256,
};

/// Checks [build]'s generated bundle in [directory], a release's downloaded
/// assets, against [recorded], the `generated` object of the
/// `build_info.json` there, and returns its sha256.
Future<String> checkRecordedGenerated(
  String directory,
  GrammarBuild build,
  Map<String, Object?> recorded,
) async {
  final commit = build.entry['commit']! as String;
  final name = generatedBundleName(build.name, commit);
  final record = recorded[build.name];
  if (record is! Map<String, Object?> ||
      record['file'] != '$sourcesDirectoryName/$name' ||
      record['commit'] != commit) {
    throw GeneratedSourcesException(
      '${build.name}: build_info.json records no generated bundle '
      '$sourcesDirectoryName/$name',
    );
  }
  final bundle = p.join(directory, name);
  if (!File(bundle).existsSync()) {
    throw GeneratedSourcesException('${build.name}: no $bundle');
  }
  final digest = await fileSha256(bundle);
  if (digest != record['sha256']) {
    throw GeneratedSourcesException(
      '${build.name}: $bundle has sha256 $digest; build_info.json records '
      '${record['sha256']}',
    );
  }
  return digest;
}

/// The digest of what the pinned CLI generates for [build], whose
/// repository is extracted under [sourceRoot], at language ABI [abi],
/// generated into a directory under [scratch].
Future<String> generatedDigest({
  required String root,
  required Toolchain toolchain,
  required GrammarBuild build,
  required String sourceRoot,
  required int abi,
  required String scratch,
}) async {
  final output = p.join(scratch, build.name);
  await generateParser(
    cli: await ensureCli(root, toolchain),
    grammarDirectory: p.normalize(
      p.join(sourceRoot, build.repository, build.path),
    ),
    outputDirectory: output,
    abi: abi,
  );
  return filesDigest(await unpackedFiles(output));
}
