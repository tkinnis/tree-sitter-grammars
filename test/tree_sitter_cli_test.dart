import 'dart:io';

import 'package:checks/checks.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../tool/src/build_platform.dart';
import '../tool/src/toolchain.dart';
import '../tool/src/tree_sitter_cli.dart';

const _executable = '#!/bin/sh\necho tree-sitter 0.27.0\n';

/// The sha256 of [bytes], computed by openssl rather than by the code
/// under test.
String _sha256(List<int> bytes, String scratch) {
  final file = File(p.join(scratch, 'digest-input'))..writeAsBytesSync(bytes);
  final result = Process.runSync('openssl', [
    'dgst',
    '-sha256',
    '-r',
    file.path,
  ]);
  return (result.stdout as String).split(' ').first;
}

Toolchain _toolchain(String sha256) => Toolchain(
  treeSitterTag: 'v0.27.0',
  treeSitterCommit: '6070dbfefd326bd735e5683eb128cc1b57dad0c0',
  treeSitterFilesSha256:
      '8284859e50207152e5df621e49086ea169020c47ef342489f5f8c06b7082f2ea',
  cliVersion: '0.27.0',
  cliAsset: 'tree-sitter-macos-arm64.gz',
  cliSha256: sha256,
  arch: 'arm64',
  deploymentTarget: '13.0',
  cliPins: {
    'linux': {'arm64': (asset: 'tree-sitter-linux-arm64.gz', sha256: sha256)},
    'windows': {
      'arm64': (asset: 'tree-sitter-windows-arm64.gz', sha256: sha256),
    },
  },
);

/// The macOS CLI, which every test but the last asks for whatever the
/// platform it runs on.
const _macos = BuildPlatform.macosArm64;

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
    final cli = await ensureCli(
      root,
      toolchain,
      download: serving(asset),
      platform: _macos,
    );

    check(downloads).deepEquals([toolchain.cliUrl]);
    check(File(cli).readAsStringSync()).equals(_executable);
    // NTFS keeps no mode for chmod to set.
    if (!Platform.isWindows) {
      check(File(cli).statSync().modeString()).equals('rwxr-xr-x');
    }
  });

  test('on Windows, downloads the asset its architecture pins as an '
      '.exe', () async {
    final cli = await ensureCli(
      root,
      toolchain,
      download: serving(asset),
      platform: BuildPlatform.windowsArm64,
    );

    check(
      downloads,
    ).deepEquals([toolchain.cliUrlFor(BuildPlatform.windowsArm64)]);
    check(p.basename(cli)).equals('tree-sitter-0.27.0.exe');
    check(File(cli).readAsStringSync()).equals(_executable);
  });

  test('on Linux, downloads the asset its architecture pins, with no '
      'extension', () async {
    final cli = await ensureCli(
      root,
      toolchain,
      download: serving(asset),
      platform: BuildPlatform.linuxArm64,
    );

    check(
      downloads,
    ).deepEquals([toolchain.cliUrlFor(BuildPlatform.linuxArm64)]);
    check(
      File(
        cached('tree-sitter-0.27.0-tree-sitter-linux-arm64.gz'),
      ).existsSync(),
    ).isTrue();
    check(p.basename(cli)).equals('tree-sitter-0.27.0');
    check(File(cli).readAsStringSync()).equals(_executable);
  });

  test('refuses an asset whose sha256 is not the pinned one', () async {
    final tampered = gzip.encode('#!/bin/sh\necho evil\n'.codeUnits);

    await check(
      ensureCli(root, toolchain, download: serving(tampered), platform: _macos),
    ).throws<CliException>(
      (it) => it
          .has((e) => e.message, 'message')
          .contains('toolchain.json expects ${toolchain.cliSha256}'),
    );
    check(File(cached('tree-sitter-0.27.0')).existsSync()).isFalse();
  });

  test('uses a cached asset and rewrites a modified executable', () async {
    await ensureCli(
      root,
      toolchain,
      download: serving(asset),
      platform: _macos,
    );
    File(cached('tree-sitter-0.27.0')).writeAsStringSync('modified');

    final cli = await ensureCli(
      root,
      toolchain,
      download: serving(asset),
      platform: _macos,
    );

    check(downloads).length.equals(1);
    check(File(cli).readAsStringSync()).equals(_executable);
  });

  test('downloads again when the cached asset is wrong', () async {
    File(cached('tree-sitter-0.27.0-tree-sitter-macos-arm64.gz'))
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync([0]);

    await ensureCli(
      root,
      toolchain,
      download: serving(asset),
      platform: _macos,
    );

    check(downloads).length.equals(1);
  });

  group('the asset is decompressed to cliAssetLimit and no further', () {
    // A small asset can decode to far more than memory holds; each case
    // lowers cliAssetLimit, to refuse an asset without allocating it.
    test('the limit is 256 MiB', () {
      // Eleven times the 23 MiB the largest pinned asset decodes to.
      // Mutation: any other cliAssetLimit; this reddens.
      check(cliAssetLimit).equals(256 << 20);
    });

    test('an asset one byte past it is refused', () async {
      // Mutation: decompress with gzip.decode, or to another limit than
      // cliAssetLimit; this reddens.
      final limit = cliAssetLimit;
      addTearDown(() => cliAssetLimit = limit);
      cliAssetLimit = _executable.length - 1;

      await check(
        ensureCli(root, toolchain, download: serving(asset), platform: _macos),
      ).throws<CliException>(
        (it) => it
            .has((e) => e.message, 'message')
            .equals(
              'could not decompress '
              '${cached('tree-sitter-0.27.0-tree-sitter-macos-arm64.gz')}: '
              'it decodes to more than ${_executable.length - 1} bytes, the '
              'most its reader allows',
            ),
      );
      check(File(cached('tree-sitter-0.27.0')).existsSync()).isFalse();

      // The control: exactly its limit is read.
      cliAssetLimit = _executable.length;
      final cli = await ensureCli(
        root,
        toolchain,
        download: serving(asset),
        platform: _macos,
      );
      check(File(cli).readAsStringSync()).equals(_executable);
    });

    test('an asset that is not one whole gzip member is refused', () async {
      // gzip.decode ignores a byte after the trailer; gunzip refuses it.
      // Mutation: decompress with gzip.decode; this reddens.
      final trailing = [...asset, 0];
      toolchain = _toolchain(_sha256(trailing, root));

      await check(
        ensureCli(
          root,
          toolchain,
          download: serving(trailing),
          platform: _macos,
        ),
      ).throws<CliException>(
        (it) => it
            .has((e) => e.message, 'message')
            .endsWith('-macos-arm64.gz: 1 byte follows its trailer'),
      );
    });
  });

  test('generateParser refuses a grammar that commits parser.c', () async {
    File(p.join(root, 'grammar', 'src', 'parser.c'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('');

    await check(
      generateParser(
        cli: '/nonexistent/tree-sitter',
        grammarDirectory: p.join(root, 'grammar'),
        outputDirectory: p.join(root, 'gen'),
        abi: 15,
      ),
    ).throws<CliException>(
      (it) => it
          .has((e) => e.message, 'message')
          .contains('commits src/parser.c; it is never generated'),
    );
    check(Directory(p.join(root, 'gen')).existsSync()).isFalse();
  });
}
