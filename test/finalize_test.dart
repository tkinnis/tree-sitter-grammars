import 'dart:convert';
import 'dart:io';

import 'package:checks/checks.dart';
import 'package:test/test.dart';

import '../tool/src/build_platform.dart';
import '../tool/src/finalize.dart';
import '../tool/src/github.dart';
import '../tool/src/tar.dart';
import 'support/release_fixture.dart';

typedef _Assets = List<Map<String, Object?>>;

const _platforms = [
  BuildPlatform.macosArm64,
  BuildPlatform.linuxArm64,
  BuildPlatform.windowsX64,
];

/// A draft with every platform's archive attached, and the finalize that
/// publishes it; each field can be replaced to make the finalize refuse
/// for one reason.
class _Finalize {
  _Finalize({
    this.required = _platforms,
    this.edit,
    this.sidecars = const {},
    this.downloads = const {},
    this.listed,
    this.extra = const {},
    String? linuxGlibc = '2.17',
  }) : linuxArchive = _archive(linuxGlibc);

  final List<BuildPlatform> required;
  final _Assets Function(_Assets)? edit;
  final Map<String, String> sidecars;
  final Map<String, List<int>> downloads;
  final List<Map<String, Object?>>? listed;
  final Map<String, Object> extra;
  final List<int> linuxArchive;
  final calls = <List<String>>[];

  static List<int> _archive(String? glibc) => gzipCompress(
    ustar([
      (
        path: 'grammars/build_info.json',
        bytes: utf8.encode(
          jsonEncode(buildInfoJson(platform: 'linux-arm64', glibc: glibc)),
        ),
        mode: 420,
        epoch: 0,
      ),
    ]),
  );

  String get infoText => jsonEncode(buildInfoJson());

  String shaOf(BuildPlatform platform) => switch (platform) {
    BuildPlatform.linuxArm64 => dartSha256(linuxArchive),
    _ => dartSha256(utf8.encode(platform.id)),
  };

  String sidecarOf(BuildPlatform platform) =>
      sidecars[platform.releaseArchiveName] ??
      '${shaOf(platform)}  ${platform.releaseArchiveName}\n';

  _Assets get assets {
    final all = [
      assetJson('build_info.json', dartSha256(utf8.encode(infoText))),
      assetJson('tree-sitter-0.tar.gz', 'bb'),
      assetJson('latex-0.tar.gz', 'b2'),
      assetJson('swift-gen.tar.gz', 'cc'),
      for (final platform in _platforms) ...[
        assetJson(platform.releaseArchiveName, shaOf(platform)),
        assetJson(
          '${platform.releaseArchiveName}.sha256',
          dartSha256(utf8.encode(sidecarOf(platform))),
        ),
      ],
    ];
    return edit?.call(all) ?? all;
  }

  Map<String, Object> get _downloads => {
    fixtureAsset(fixtureAssetId('build_info.json')): ghResult(
      0,
      stdout: infoText,
    ),
    for (final platform in _platforms)
      fixtureAsset(fixtureAssetId('${platform.releaseArchiveName}.sha256')):
          ghResult(0, stdout: sidecarOf(platform)),
    fixtureAsset(fixtureAssetId('grammars-linux-arm64.tar.gz')): ghResult(
      0,
      stdout: linuxArchive,
    ),
    for (final MapEntry(:key, :value) in downloads.entries)
      fixtureAsset(fixtureAssetId(key)): ghResult(0, stdout: value),
  };

  ProcessResult get _published => ghResult(
    0,
    stdout: jsonEncode(
      releaseJson(draft: false, immutable: true, assets: assets),
    ),
  );

  Future<Map<String, String>> run() => finalizeRelease(
    tag: 'v1.1.0',
    tagObject: fixtureTagObject,
    commit: fixtureCommit,
    platforms: required,
    run: fakeGh({
      ...fixturePushed,
      fixtureListing: listing(listed ?? [releaseJson(assets: assets)]),
      ..._downloads,
      fixtureById: [ghResult(0, stdout: '{}'), _published],
      ...extra,
    }, calls),
  );

  Iterable<List<String>> get patches =>
      calls.where((call) => call.contains('PATCH'));
}

Future<void> _refuses(_Finalize finalize, String message) =>
    check(finalize.run()).throws<PublishException>(
      (it) => it.has((e) => e.message, 'message').contains(message),
    );

/// Requires [finalize] to refuse with [message] before it publishes.
Future<void> _refusesToPublish(_Finalize finalize, String message) async {
  await _refuses(finalize, message);
  check(finalize.patches).isEmpty();
}

_Assets _without(_Assets assets, String name) => [
  for (final asset in assets)
    if (asset['name'] != name) asset,
];

_Assets _withDigest(_Assets assets, String name, String? digest) => [
  for (final asset in assets)
    if (asset['name'] == name)
      {
        for (final MapEntry(:key, :value) in asset.entries)
          if (key != 'digest') key: value,
        'digest': ?digest,
      }
    else
      asset,
];

void main() {
  group('publishes the draft', () {
    test(
      'after checking it, and returns the digests of the archives',
      () async {
        final finalize = _Finalize();

        final digests = await finalize.run();

        check(digests).deepEquals({
          for (final platform in _platforms)
            platform.id: finalize.shaOf(platform),
        });
        check(finalize.patches).length.equals(1);
        final patch = finalize.patches.single;
        check(patch.take(7)).deepEquals([
          'api',
          'repos/$releaseRepository/releases/$fixtureReleaseId',
          '-X',
          'PATCH',
          '-F',
          'draft=false',
          '-f',
        ]);
        check(patch[7]).startsWith('body=notes\n');
        check(patch[7])
          ..contains(
            '| linux-arm64 | `${finalize.shaOf(BuildPlatform.linuxArm64)}` '
            '| 2.17 |',
          )
          ..contains(
            '| macos-arm64 | `${finalize.shaOf(BuildPlatform.macosArm64)}` '
            '| |',
          )
          ..contains(
            '| windows-x64 | `${finalize.shaOf(BuildPlatform.windowsX64)}` '
            '| |',
          );
      },
    );

    test('checking the tag before and after', () async {
      final finalize = _Finalize();

      await finalize.run();

      final steps = finalize.calls.map((call) => call.take(2).join(' '));
      check(steps.first).equals(fixtureRef);
      final patch = steps.toList().indexWhere((s) => s == fixtureById);
      check(
        steps.skip(patch).take(3),
      ).deepEquals([fixtureById, fixtureRef, fixtureTag]);
    });
  });

  group('refuses, publishing nothing,', () {
    test('no platform required', () {
      return _refusesToPublish(
        _Finalize(required: const []),
        'checking the platforms: --require names no platform',
      );
    });

    test('a tag not pushed', () {
      return _refusesToPublish(
        _Finalize(
          extra: {fixtureRef: ghResult(1, stderr: 'gh: Not Found (HTTP 404)')},
        ),
        'before finalizing, GitHub could not resolve v1.1.0',
      );
    });

    test('a tag naming another commit', () {
      return _refusesToPublish(
        _Finalize(
          extra: {
            fixtureTag: ghResult(0, stdout: 'commit $fixtureOtherCommit\n'),
          },
        ),
        'before finalizing, v1.1.0 on GitHub names commit',
      );
    });

    test('no release of the tag', () {
      return _refusesToPublish(
        _Finalize(listed: const []),
        'finding the draft: no release of v1.1.0',
      );
    });

    test('a release already published', () {
      return _refusesToPublish(
        _Finalize(listed: [releaseJson(draft: false)]),
        'finding the draft: v1.1.0 is not a draft',
      );
    });

    test('a draft targeting a branch', () {
      return _refusesToPublish(
        _Finalize(listed: [releaseJson(target: 'main')]),
        'finding the draft: v1.1.0 targets main, not $fixtureCommit',
      );
    });

    test('a release GitHub reports as immutable', () {
      return _refusesToPublish(
        _Finalize(listed: [releaseJson(immutable: true)]),
        'finding the draft: v1.1.0 is immutable',
      );
    });

    for (final platform in _platforms) {
      for (final name in [
        platform.releaseArchiveName,
        '${platform.releaseArchiveName}.sha256',
      ]) {
        test('a draft without $name', () {
          return _refusesToPublish(
            _Finalize(edit: (assets) => _without(assets, name)),
            'checking the assets: $name is missing',
          );
        });
      }
    }

    test('a draft without build_info.json', () {
      return _refusesToPublish(
        _Finalize(edit: (assets) => _without(assets, 'build_info.json')),
        'checking the assets: build_info.json is missing',
      );
    });

    test('a draft without a source bundle', () {
      return _refusesToPublish(
        _Finalize(edit: (assets) => _without(assets, 'latex-0.tar.gz')),
        'checking the assets: latex-0.tar.gz is missing',
      );
    });

    test('a draft without a generated bundle', () {
      return _refusesToPublish(
        _Finalize(edit: (assets) => _without(assets, 'swift-gen.tar.gz')),
        'checking the assets: swift-gen.tar.gz is missing',
      );
    });

    test('an asset nothing accounts for', () {
      return _refusesToPublish(
        _Finalize(edit: (assets) => [...assets, assetJson('stray.bin', 'ab')]),
        'checking the assets: stray.bin is not an asset of v1.1.0',
      );
    });

    test('the archive of a platform that is not required', () {
      return _refusesToPublish(
        _Finalize(
          required: const [BuildPlatform.macosArm64, BuildPlatform.linuxArm64],
        ),
        'checking the assets: grammars-windows-x64.tar.gz is not an asset',
      );
    });

    test('an archive GitHub reports with another digest than its .sha256', () {
      return _refusesToPublish(
        _Finalize(
          sidecars: {
            'grammars-macos-arm64.tar.gz':
                '${'0' * 64}  grammars-macos-arm64.tar.gz\n',
          },
        ),
        'checking the digests: grammars-macos-arm64.tar.gz: GitHub reports '
        'sha256:',
      );
    });

    test('a .sha256 that names another file', () {
      final finalize = _Finalize();
      return _refusesToPublish(
        _Finalize(
          sidecars: {
            'grammars-windows-x64.tar.gz':
                '${finalize.shaOf(BuildPlatform.windowsX64)}  other.tar.gz\n',
          },
        ),
        'checking the digests: grammars-windows-x64.tar.gz.sha256 holds',
      );
    });

    test('a .sha256 that holds no sha256', () {
      return _refusesToPublish(
        _Finalize(
          sidecars: {
            'grammars-macos-arm64.tar.gz': 'zz  grammars-macos-arm64.tar.gz\n',
          },
        ),
        'checking the digests: grammars-macos-arm64.tar.gz.sha256 holds',
      );
    });

    test('an archive GitHub gives no digest', () {
      return _refusesToPublish(
        _Finalize(
          edit: (assets) =>
              _withDigest(assets, 'grammars-linux-arm64.tar.gz', null),
        ),
        'checking the digests: grammars-linux-arm64.tar.gz: GitHub reports '
        'null',
      );
    });

    test('a .sha256 whose own digest is not its content\'s', () {
      return _refusesToPublish(
        _Finalize(
          edit: (assets) => _withDigest(
            assets,
            'grammars-macos-arm64.tar.gz.sha256',
            'sha256:zz',
          ),
        ),
        'checking the digests: grammars-macos-arm64.tar.gz.sha256: GitHub '
        'reports sha256:zz',
      );
    });

    test('a bundle with another digest than build_info.json records', () {
      return _refusesToPublish(
        _Finalize(
          edit: (assets) =>
              _withDigest(assets, 'tree-sitter-0.tar.gz', 'sha256:xx'),
        ),
        'checking the digests: tree-sitter-0.tar.gz: GitHub reports '
        'sha256:xx, build_info.json records bb',
      );
    });

    test('a Linux archive that is not the bytes GitHub has the digest of', () {
      return _refusesToPublish(
        _Finalize(
          downloads: {
            'grammars-linux-arm64.tar.gz': [1, 2, 3],
          },
        ),
        'reading the notes: grammars-linux-arm64.tar.gz as downloaded has '
        'sha256',
      );
    });

    test('a Linux archive that records no glibc', () {
      return _refusesToPublish(
        _Finalize(linuxGlibc: null),
        'reading the notes: grammars-linux-arm64.tar.gz records no '
        'glibcRequirement',
      );
    });
  });

  test('fails when the publication fails', () {
    return _refuses(
      _Finalize(
        extra: {
          fixtureById: [ghResult(1, stderr: 'HTTP 422')],
        },
      ),
      'publishing: gh api PATCH v1.1.0 failed: HTTP 422',
    );
  });

  test('fails when the tag moves while it publishes', () {
    return _refuses(
      _Finalize(
        extra: {
          fixtureTag: [
            ghResult(0, stdout: 'commit $fixtureCommit\n'),
            ghResult(0, stdout: 'commit $fixtureOtherCommit\n'),
          ],
        },
      ),
      'after finalizing, v1.1.0 on GitHub names commit',
    );
  });

  group('fails reading back', () {
    Future<void> failsWith(
      ProcessResult Function(_Finalize) readBack,
      String message,
    ) {
      final finalize = _Finalize();
      return _refuses(
        _Finalize(
          extra: {
            fixtureById: [ghResult(0, stdout: '{}'), readBack(finalize)],
          },
        ),
        message,
      );
    }

    ProcessResult release(
      _Finalize finalize, {
      bool draft = false,
      bool immutable = true,
      _Assets Function(_Assets)? edit,
    }) => ghResult(
      0,
      stdout: jsonEncode(
        releaseJson(
          draft: draft,
          immutable: immutable,
          assets: edit?.call(finalize.assets) ?? finalize.assets,
        ),
      ),
    );

    test('a release not reported immutable', () {
      return failsWith(
        (f) => release(f, immutable: false),
        'reading back: v1.1.0 is not reported immutable',
      );
    });

    test('a release still a draft', () {
      return failsWith(
        (f) => release(f, draft: true),
        'reading back: v1.1.0 is still a draft',
      );
    });

    test('an asset whose digest changed', () {
      return failsWith(
        (f) => release(
          f,
          edit: (assets) =>
              _withDigest(assets, 'swift-gen.tar.gz', 'sha256:changed'),
        ),
        'reading back: swift-gen.tar.gz was sha256:cc, GitHub reports '
        'sha256:changed',
      );
    });

    test('an asset that went', () {
      return failsWith(
        (f) => release(f, edit: (assets) => _without(assets, 'latex-0.tar.gz')),
        'reading back: latex-0.tar.gz is gone',
      );
    });

    test('an asset that came', () {
      return failsWith(
        (f) => release(f, edit: (assets) => [...assets, assetJson('x', 'ab')]),
        'reading back: x is an asset nobody uploaded',
      );
    });
  });
}
