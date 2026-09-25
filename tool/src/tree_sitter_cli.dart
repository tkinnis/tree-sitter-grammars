/// Supplies the pinned tree-sitter CLI and generates the parsers of the
/// grammars that commit none.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import 'compiler.dart';
import 'toolchain.dart';

/// Thrown when the CLI cannot be supplied or a generation fails.
final class CliException implements Exception {
  const CliException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The sha256 of [path], as `shasum -a 256` computes it.
Future<String> sha256Of(String path) async {
  final result = await Process.run('shasum', ['-a', '256', path]);
  if (result.exitCode != 0) {
    throw CliException('shasum $path failed: ${result.stderr}');
  }
  return (result.stdout as String).split(' ').first;
}

/// Fetches [url] into the file [destination].
typedef Downloader = Future<void> Function(Uri url, String destination);

/// Returns the path of the pinned CLI under [root]`/.cache/`, fetching its
/// release asset with [download] when it is absent or its digest is wrong.
///
/// The asset's sha256 is checked against `toolchain.json` every time, and
/// the executable is decompressed afresh from the checked asset, so a
/// modified executable in the cache never runs. Throws a [CliException]
/// when the fetched asset's digest is not the pinned one.
Future<String> ensureCli(
  String root,
  Toolchain toolchain, {
  Downloader download = _download,
}) async {
  final cache = Directory(p.join(root, '.cache'))..createSync(recursive: true);
  final asset = p.join(
    cache.path,
    'tree-sitter-${toolchain.cliVersion}-'
    '${toolchain.cliAsset}',
  );
  if (!File(asset).existsSync() ||
      await sha256Of(asset) != toolchain.cliSha256) {
    await download(toolchain.cliUrl, asset);
  }
  final digest = await sha256Of(asset);
  if (digest != toolchain.cliSha256) {
    throw CliException(
      '${toolchain.cliUrl} has sha256 $digest, '
      'toolchain.json expects ${toolchain.cliSha256}',
    );
  }
  final executable = p.join(cache.path, 'tree-sitter-${toolchain.cliVersion}');
  File(
    executable,
  ).writeAsBytesSync(gzip.decode(File(asset).readAsBytesSync()), flush: true);
  final chmod = await Process.run('chmod', ['755', executable]);
  if (chmod.exitCode != 0) throw CliException('chmod: ${chmod.stderr}');
  return executable;
}

Future<void> _download(Uri url, String destination) async {
  final client = HttpClient();
  try {
    final response = await (await client.getUrl(url)).close();
    if (response.statusCode != HttpStatus.ok) {
      throw CliException('GET $url returned HTTP ${response.statusCode}');
    }
    final partial = '$destination.partial';
    await response.pipe(File(partial).openWrite());
    File(partial).renameSync(destination);
  } finally {
    client.close();
  }
}

/// Generates the parser of the grammar in [grammarDirectory] from its
/// `src/grammar.json` into [outputDirectory], at language ABI [abi].
///
/// The CLI runs with the same minimal environment as the compiler, so no
/// `TREE_SITTER_*` variable of the user's changes what it writes.
Future<void> generateParser({
  required String cli,
  required String grammarDirectory,
  required String outputDirectory,
  required int abi,
}) async {
  if (File(p.join(grammarDirectory, 'src', 'parser.c')).existsSync()) {
    throw CliException(
      '$grammarDirectory commits src/parser.c; '
      'it is never generated',
    );
  }
  Directory(outputDirectory).createSync(recursive: true);
  final result = await Process.run(
    cli,
    ['generate', 'src/grammar.json', '--abi', '$abi', '-o', outputDirectory],
    workingDirectory: grammarDirectory,
    environment: compilerEnvironment(Platform.environment),
    includeParentEnvironment: false,
  );
  if (result.exitCode != 0) {
    throw CliException(
      'tree-sitter generate in $grammarDirectory exited '
      '${result.exitCode}\n${result.stdout}${result.stderr}',
    );
  }
  if (!File(p.join(outputDirectory, 'parser.c')).existsSync()) {
    throw CliException(
      'tree-sitter generate wrote no parser.c to '
      '$outputDirectory',
    );
  }
}
