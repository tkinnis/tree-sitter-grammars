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
    this.absent = const [BuildPlatform.windowsArm64],
    this.edit,
    this.sidecars = const {},
    this.downloads = const {},
    this.listed,
    this.extra = const {},
    this.linuxGlibc = '2.17',
    this.embedded = const {},
    this.draftInfo,
    this.reread,
    this.readBack,
  }) {
    for (final platform in _platforms) {
      archives[platform] = gzipCompress(
        ustar([
          (
            path: 'grammars/build_info.json',
            bytes: utf8.encode(
              jsonEncode(
                embedded[platform] ??
                    buildInfoJson(
                      platform: platform.id,
                      glibc: platform.isLinux ? linuxGlibc : null,
                    ),
              ),
            ),
            mode: 420,
            epoch: 0,
          ),
        ]),
      );
    }
  }

  final List<BuildPlatform> required;
  final List<BuildPlatform> absent;
  final _Assets Function(_Assets)? edit;
  final Map<String, String> sidecars;
  final Map<String, List<int>> downloads;
  final List<Map<String, Object?>>? listed;
  final Map<String, Object> extra;
  final String? linuxGlibc;
  final Map<BuildPlatform, Map<String, Object?>> embedded;
  final Map<String, Object?>? draftInfo;

  /// The release as read just before it is published, when not the draft.
  final ProcessResult? reread;

  /// The release as read back after it is published, when not the one
  /// published.
  final ProcessResult Function(_Finalize)? readBack;
  final archives = <BuildPlatform, List<int>>{};
  final calls = <List<String>>[];

  String get infoText => jsonEncode(draftInfo ?? buildInfoJson());

  String shaOf(BuildPlatform platform) => dartSha256(archives[platform]!);

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
    for (final platform in _platforms) ...{
      fixtureAsset(fixtureAssetId('${platform.releaseArchiveName}.sha256')):
          ghResult(0, stdout: sidecarOf(platform)),
      fixtureAsset(fixtureAssetId(platform.releaseArchiveName)): ghResult(
        0,
        stdout: archives[platform]!,
      ),
    },
    for (final MapEntry(:key, :value) in downloads.entries)
      fixtureAsset(fixtureAssetId(key)): ghResult(0, stdout: value),
  };

  ProcessResult get _draft =>
      ghResult(0, stdout: jsonEncode(releaseJson(assets: assets)));

  ProcessResult get published => ghResult(
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
    absent: absent,
    run: fakeGh({
      ...fixturePushed,
      fixtureImmutable: ghResult(0, stdout: '{"enabled": true}'),
      fixtureListing: listing(listed ?? [releaseJson(assets: assets)]),
      ..._downloads,
      fixturePatch: ghResult(0, stdout: '{}'),
      fixtureById: [reread ?? _draft, readBack?.call(this) ?? published],
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
          )
          ..contains('| windows-arm64 | not in this release | |');
      },
    );

    test('checking immutable releases first, then the tag and the draft '
        'again just before and the tag again just after', () async {
      final finalize = _Finalize();

      await finalize.run();

      final steps = finalize.calls
          .map(
            (call) =>
                call.contains('PATCH') ? fixturePatch : call.take(2).join(' '),
          )
          .toList();
      check(steps.first).equals(fixtureImmutable);
      final patch = steps.indexOf(fixturePatch);
      check(steps.skip(patch - 3).take(7)).deepEquals([
        fixtureRef,
        fixtureTag,
        fixtureById,
        fixturePatch,
        fixtureRef,
        fixtureTag,
        fixtureById,
      ]);
    });
  });

  group('refuses, publishing nothing,', () {
    test('no platform required', () {
      return _refusesToPublish(
        _Finalize(required: const []),
        'checking the platforms: --require names no platform',
      );
    });

    test('a platform the repository builds that is neither required nor '
        'allowed missing', () {
      return _refusesToPublish(
        _Finalize(absent: const []),
        'checking the platforms: windows-arm64 is neither required nor '
        'allowed missing',
      );
    });

    test('a platform both required and allowed missing', () {
      return _refusesToPublish(
        _Finalize(
          absent: const [BuildPlatform.windowsArm64, BuildPlatform.linuxArm64],
        ),
        'checking the platforms: linux-arm64 is both required and allowed '
        'missing',
      );
    });

    test('immutable releases that are not enabled', () {
      return _refusesToPublish(
        _Finalize(
          extra: {fixtureImmutable: ghResult(0, stdout: '{"enabled": false}')},
        ),
        'checking immutable releases: they are not enabled on '
        '$releaseRepository',
      );
    });

    test('immutable releases GitHub will not answer for', () {
      return _refusesToPublish(
        _Finalize(extra: {fixtureImmutable: ghResult(1, stderr: 'HTTP 404')}),
        'checking immutable releases: HTTP 404',
      );
    });

    test('immutable releases answered without enabled', () {
      return _refusesToPublish(
        _Finalize(extra: {fixtureImmutable: ghResult(0, stdout: '{}')}),
        'checking immutable releases: they are not enabled',
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
          absent: const [BuildPlatform.windowsArm64, BuildPlatform.windowsX64],
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
        'checking the archives: grammars-linux-arm64.tar.gz as downloaded has '
        'sha256',
      );
    });

    test('a Linux archive that records no glibc', () {
      return _refusesToPublish(
        _Finalize(linuxGlibc: null),
        'checking the archives: grammars-linux-arm64.tar.gz records no '
        'glibcRequirement',
      );
    });

    for (final platform in _platforms) {
      test('${platform.id} archive that is not the bytes GitHub has the '
          'digest of', () {
        return _refusesToPublish(
          _Finalize(
            downloads: {
              platform.releaseArchiveName: [1, 2, 3],
            },
          ),
          'checking the archives: ${platform.releaseArchiveName} as '
          'downloaded has sha256',
        );
      });

      test('${platform.id} archive that records another release', () {
        return _refusesToPublish(
          _Finalize(
            embedded: {
              platform: buildInfoJson(
                platform: platform.id,
                release: 'v1.0.0',
                glibc: platform.isLinux ? '2.17' : null,
              ),
            },
          ),
          'checking the archives: ${platform.releaseArchiveName}: its '
          'build_info.json records the release v1.0.0, not v1.1.0',
        );
      });

      test('${platform.id} archive that records another commit', () {
        return _refusesToPublish(
          _Finalize(
            embedded: {
              platform: buildInfoJson(
                platform: platform.id,
                commit: fixtureOtherCommit,
                glibc: platform.isLinux ? '2.17' : null,
              ),
            },
          ),
          'checking the archives: ${platform.releaseArchiveName}: its '
          'build_info.json records the commit $fixtureOtherCommit',
        );
      });

      test('${platform.id} archive that records another platform', () {
        return _refusesToPublish(
          _Finalize(
            embedded: {platform: buildInfoJson(platform: 'windows-arm64')},
          ),
          'checking the archives: ${platform.releaseArchiveName}: its '
          'build_info.json records the platform windows-arm64, not '
          '${platform.id}',
        );
      });

      test('${platform.id} archive built from other bundles', () {
        return _refusesToPublish(
          _Finalize(
            embedded: {
              platform: buildInfoJson(
                platform: platform.id,
                glibc: platform.isLinux ? '2.17' : null,
                sources: {'tree-sitter': 'ff', 'latex': 'b2'},
              ),
            },
          ),
          'checking the sources: tree-sitter',
        );
      });
    }

    test('a draft build_info.json of another release', () {
      return _refusesToPublish(
        _Finalize(draftInfo: buildInfoJson(release: 'v1.0.0')),
        "checking the draft: the draft's build_info.json records the release "
        'v1.0.0, not v1.1.0',
      );
    });

    test('a draft build_info.json of another commit', () {
      return _refusesToPublish(
        _Finalize(draftInfo: buildInfoJson(commit: fixtureOtherCommit)),
        'checking the draft: ',
      );
    });

    test('a draft build_info.json that records no sources', () {
      return _refusesToPublish(
        _Finalize(draftInfo: buildInfoJson(sources: const {})),
        'checking the draft: build_info.json records no sources',
      );
    });

    test('a draft build_info.json that records no generated sources', () {
      return _refusesToPublish(
        _Finalize(draftInfo: buildInfoJson(generated: const {})),
        'checking the draft: build_info.json records no generated',
      );
    });

    for (final key in ['sources', 'generated']) {
      for (final (label, record) in [
        ('no file', {'sha256': 'bb'}),
        ('no sha256', {'file': 'sources/x.tar.gz'}),
        ('a non-string file', {'file': 3, 'sha256': 'bb'}),
        ('a record that is not an object', 'x'),
      ]) {
        test('a draft build_info.json whose $key has $label', () {
          final info = buildInfoJson();
          info[key] = {
            ...(info[key]! as Map<String, Object?>),
            'broken': record,
          };
          return _refusesToPublish(
            _Finalize(draftInfo: info),
            'checking the draft: build_info.json records a malformed bundle '
            '$key.broken',
          );
        });
      }
    }

    test('a draft build_info.json that records a bundle twice', () {
      final info = buildInfoJson();
      info['sources'] = {
        ...(info['sources']! as Map<String, Object?>),
        'dup': {'file': 'sources/tree-sitter-0.tar.gz', 'sha256': 'bb'},
      };
      return _refusesToPublish(
        _Finalize(draftInfo: info),
        'checking the draft: build_info.json records tree-sitter-0.tar.gz '
        'twice',
      );
    });

    for (final (label, sidecar) in [
      (
        'no trailing newline',
        (String sha) => '$sha  grammars-macos-arm64.tar.gz',
      ),
      (
        'two trailing newlines',
        (String sha) => '$sha  grammars-macos-arm64.tar.gz\n\n',
      ),
      (
        'uppercase hex',
        (String sha) => '${sha.toUpperCase()}  grammars-macos-arm64.tar.gz\n',
      ),
      ('one space', (String sha) => '$sha grammars-macos-arm64.tar.gz\n'),
    ]) {
      test('a .sha256 with $label', () {
        final sha = _Finalize().shaOf(BuildPlatform.macosArm64);
        return _refusesToPublish(
          _Finalize(sidecars: {'grammars-macos-arm64.tar.gz': sidecar(sha)}),
          'checking the digests: grammars-macos-arm64.tar.gz.sha256 holds',
        );
      });
    }

    test('an asset GitHub has not finished', () {
      return _refusesToPublish(
        _Finalize(
          edit: (assets) => [
            for (final asset in assets)
              asset['name'] == 'latex-0.tar.gz'
                  ? assetJson('latex-0.tar.gz', 'b2', state: 'open')
                  : asset,
          ],
        ),
        'checking the assets: latex-0.tar.gz is in the state open',
      );
    });

    test('an asset in no state', () {
      return _refusesToPublish(
        _Finalize(
          edit: (assets) => [
            for (final asset in assets)
              asset['name'] == 'latex-0.tar.gz'
                  ? assetJson('latex-0.tar.gz', 'b2', state: null)
                  : asset,
          ],
        ),
        'checking the assets: latex-0.tar.gz is in the state null',
      );
    });

    group('that changed between the checks and the publication:', () {
      test('a tag moved', () {
        return _refusesToPublish(
          _Finalize(
            extra: {
              fixtureTag: [
                ghResult(0, stdout: 'commit $fixtureCommit\n'),
                ghResult(0, stdout: 'commit $fixtureOtherCommit\n'),
              ],
            },
          ),
          'before publishing, v1.1.0 on GitHub names commit',
        );
      });

      Future<void> changes(
        ProcessResult Function(_Finalize) change,
        String message,
      ) {
        final base = _Finalize();
        return _refusesToPublish(_Finalize(reread: change(base)), message);
      }

      ProcessResult release(
        _Finalize f, {
        bool draft = true,
        String target = fixtureCommit,
        _Assets Function(_Assets)? edit,
      }) => ghResult(
        0,
        stdout: jsonEncode(
          releaseJson(
            draft: draft,
            target: target,
            assets: edit?.call(f.assets) ?? f.assets,
          ),
        ),
      );

      test('the release stopped being a draft', () {
        return changes(
          (f) => release(f, draft: false),
          'before publishing: v1.1.0 is no longer a draft',
        );
      });

      test('the target moved', () {
        return changes(
          (f) => release(f, target: fixtureOtherCommit),
          'before publishing: v1.1.0 targets $fixtureOtherCommit now',
        );
      });

      test('an asset was replaced by one of the same name and digest', () {
        return changes(
          (f) => release(
            f,
            edit: (assets) => [
              for (final asset in assets)
                asset['name'] == 'latex-0.tar.gz'
                    ? {...asset, 'id': 99999}
                    : asset,
            ],
          ),
          'before publishing: latex-0.tar.gz is a different asset now',
        );
      });

      test('the notes were edited', () {
        final base = _Finalize();
        return _refusesToPublish(
          _Finalize(
            reread: ghResult(
              0,
              stdout: jsonEncode(
                releaseJson(body: 'edited', assets: base.assets),
              ),
            ),
          ),
          'before publishing: the notes of v1.1.0 were edited',
        );
      });

      test('an asset changed state', () {
        return changes(
          (f) => release(
            f,
            edit: (assets) => [
              for (final asset in assets)
                asset['name'] == 'latex-0.tar.gz'
                    ? assetJson('latex-0.tar.gz', 'b2', state: 'open')
                    : asset,
            ],
          ),
          'before publishing: latex-0.tar.gz is in the state open now',
        );
      });

      test('an asset got another digest', () {
        return changes(
          (f) => release(
            f,
            edit: (assets) =>
                _withDigest(assets, 'latex-0.tar.gz', 'sha256:other'),
          ),
          'before publishing: latex-0.tar.gz was sha256:b2, GitHub reports '
          'sha256:other',
        );
      });

      test('an asset came', () {
        return changes(
          (f) =>
              release(f, edit: (assets) => [...assets, assetJson('x', 'ab')]),
          'before publishing: x is an asset nobody checked',
        );
      });

      test('an asset went', () {
        return changes(
          (f) => release(
            f,
            edit: (assets) => _without(assets, 'grammars-macos-arm64.tar.gz'),
          ),
          'before publishing: grammars-macos-arm64.tar.gz is gone',
        );
      });

      test('the release could not be read', () {
        return _refusesToPublish(
          _Finalize(reread: ghResult(1, stderr: 'HTTP 502')),
          'reading release',
        );
      });
    });
  });

  test('fails when the publication fails, saying the release may be '
      'published', () {
    return _refuses(
      _Finalize(extra: {fixturePatch: ghResult(1, stderr: 'HTTP 422')}),
      'publishing: gh api PATCH v1.1.0 failed: HTTP 422; if the request was '
      'applied the tag v1.1.0 is burned: do not pin these digests, and check '
      'gh release view v1.1.0',
    );
  });

  test('fails when the tag moves while it publishes', () {
    return _refuses(
      _Finalize(
        extra: {
          fixtureTag: [
            ghResult(0, stdout: 'commit $fixtureCommit\n'),
            ghResult(0, stdout: 'commit $fixtureCommit\n'),
            ghResult(0, stdout: 'commit $fixtureOtherCommit\n'),
          ],
        },
      ),
      'the tag v1.1.0 is burned',
    );
  });

  group('fails reading back', () {
    Future<void> failsWith(
      ProcessResult Function(_Finalize) readBack,
      String message,
    ) {
      return check(
        _Finalize(readBack: readBack).run(),
      ).throws<PublishException>(
        (it) => it.has((e) => e.message, 'message')
          ..contains(message)
          ..contains('v1.1.0 is published and immutable')
          ..contains('the tag v1.1.0 is burned')
          ..contains('do not pin these digests')
          ..contains('release the next version'),
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

    test('a payload of the wrong shape, saying the tag is burned', () {
      return failsWith(
        (f) => ghResult(
          0,
          stdout: jsonEncode({
            'id': fixtureReleaseId,
            'draft': false,
            'immutable': true,
            'assets': [
              {'id': 'seven', 'name': 'x'},
            ],
          }),
        ),
        'GitHub answered an asset of release',
      );
    });

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
