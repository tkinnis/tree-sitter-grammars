import 'dart:io';

import 'package:checks/checks.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../tool/src/toolchain.dart';
import '../tool/src/tree_sitter_cli.dart';

const _executable = '#!/bin/sh\necho tree-sitter 0.27.0\n';

/// The sha256 of [bytes], computed by openssl rather than by the code
/// under test.
String _sha256(List<int> bytes, String scratch) {
  final file = File(p.join(scratch, 'digest-input'))..writeAsBytesSync(bytes);
  final result =
      Process.runSync('openssl', ['dgst', '-sha256', '-r', file.path]);
  return (result.stdout as String).split(' ').first;
}

Toolchain _toolchain(String sha256) => Toolchain(
      treeSitterTag: 'v0.27.0',
      treeSitterCommit: '6070dbfefd326bd735e5683eb128cc1b57dad0c0',
      cliVersion: '0.27.0',
      cliAsset: 'tree-sitter-macos-arm64.gz',
      cliSha256: sha256,
      arch: 'arm64',
      deploymentTarget: '13.0',
    );

void main() {
  late String root;
  late List<int> asset;
  late Toolchain toolchain;
  late List<Uri> downloads;

  setUp(() {
    root = Directory.systemTemp.createTempSync('cli_test').path;
    asset = gzip.encode(_executable.codeUnits);
    toolchain = _toolchain(_sha256(asset, root));
    downloads = [];
  });

  tearDown(() => Directory(root).deleteSync(recursive: true));

  Downloader serving(List<int> bytes) => (url, destination) async {
        downloads.add(url);
        File(destination).writeAsBytesSync(bytes);
      };

  String cached(String name) => p.join(root, '.cache', name);

  test('downloads the pinned asset and decompresses it', () async {
    final cli = await ensureCli(root, toolchain, download: serving(asset));

    check(downloads).deepEquals([toolchain.cliUrl]);
    check(File(cli).readAsStringSync()).equals(_executable);
    check(File(cli).statSync().modeString()).equals('rwxr-xr-x');
  });

  test('refuses an asset whose sha256 is not the pinned one', () async {
    final tampered = gzip.encode('#!/bin/sh\necho evil\n'.codeUnits);

    await check(ensureCli(root, toolchain, download: serving(tampered)))
        .throws<CliException>((it) => it
            .has((e) => e.message, 'message')
            .contains('toolchain.json expects ${toolchain.cliSha256}'));
    check(File(cached('tree-sitter-0.27.0')).existsSync()).isFalse();
  });

  test('uses a cached asset and rewrites a modified executable', () async {
    await ensureCli(root, toolchain, download: serving(asset));
    File(cached('tree-sitter-0.27.0')).writeAsStringSync('modified');

    final cli = await ensureCli(root, toolchain, download: serving(asset));

    check(downloads).length.equals(1);
    check(File(cli).readAsStringSync()).equals(_executable);
  });

  test('downloads again when the cached asset is wrong', () async {
    File(cached('tree-sitter-0.27.0-tree-sitter-macos-arm64.gz'))
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync([0]);

    await ensureCli(root, toolchain, download: serving(asset));

    check(downloads).length.equals(1);
  });

  test('generateParser refuses a grammar that commits parser.c', () async {
    File(p.join(root, 'grammar', 'src', 'parser.c'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('');

    await check(generateParser(
      cli: '/nonexistent/tree-sitter',
      grammarDirectory: p.join(root, 'grammar'),
      outputDirectory: p.join(root, 'gen'),
      abi: 15,
    )).throws<CliException>((it) => it
        .has((e) => e.message, 'message')
        .contains('commits src/parser.c; it is never generated'));
    check(Directory(p.join(root, 'gen')).existsSync()).isFalse();
  });
}
