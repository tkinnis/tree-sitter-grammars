import 'dart:convert';
import 'dart:io';

import 'package:checks/checks.dart';
import 'package:test/test.dart';

import '../tool/src/attach.dart';
import '../tool/src/build_platform.dart';
import '../tool/src/github.dart';
import '../tool/src/tar.dart';
import 'support/release_fixture.dart';

const _archiveName = 'grammars-linux-arm64.tar.gz';
const _macosAssets = [
  'grammars-macos-arm64.tar.gz',
  'grammars-macos-arm64.tar.gz.sha256',
  'tree-sitter-0.tar.gz',
];

/// The assets a draft made by `--publish` holds, with the digests GitHub
/// reports.
List<Map<String, Object?>> _draftAssets(String infoSha256) => [
  assetJson('build_info.json', infoSha256),
  for (final name in _macosAssets) assetJson(name, 'dd'),
];

/// One attach, built from a real archive in a temporary directory.
///
/// Every field can be replaced to make the attach refuse for one reason.
class _Attach {
  _Attach(
    this.directory, {
    Map<String, Object?>? embedded,
    Map<String, Object?>? published,
    String Function(String, String)? sidecar,
    this.listed,
    this.alreadyHeld,
    this.platform = BuildPlatform.linuxArm64,
    this.afterUpload,
    this.extra = const {},
  }) {
    sha256 = writeArchive(
      directory.path,
      'linux-arm64',
      embedded ?? buildInfoJson(platform: 'linux-arm64', glibc: '2.17'),
      sidecar: sidecar,
    );
    releaseInfo = jsonEncode(published ?? buildInfoJson());
  }

  final Directory directory;
  final BuildPlatform platform;
  final List<Map<String, Object?>> Function(List<Map<String, Object?>>)?
  afterUpload;
  final Map<String, Object> extra;
  final List<Map<String, Object?>>? listed;
  final List<Map<String, Object?>> Function(String archive, String sidecar)?
  alreadyHeld;
  final calls = <List<String>>[];
  late final String sha256;
  late final String releaseInfo;

  /// The sha256 of the `.sha256` file, the digest GitHub reports of it.
  String get sidecarSha256 => dartSha256(utf8.encode(_sidecar));

  /// The two assets of this platform, as GitHub reports them once
  /// uploaded.
  List<Map<String, Object?>> get ownAssets => [
    assetJson(_archiveName, sha256),
    assetJson('$_archiveName.sha256', sidecarSha256),
  ];

  /// The draft's release object holding [assets].
  ProcessResult releaseWith(List<Map<String, Object?>> assets) =>
      ghResult(0, stdout: jsonEncode(releaseJson(assets: assets)));

  String get _infoSha256 => dartSha256(utf8.encode(releaseInfo));

  /// The draft after the upload: its assets, and the two new ones, which
  /// [afterUpload] may alter.
  ProcessResult get _readBack {
    final assets = [..._draftAssets(_infoSha256), ...ownAssets];
    return ghResult(
      0,
      stdout: jsonEncode(
        releaseJson(assets: afterUpload?.call(assets) ?? assets),
      ),
    );
  }

  String get _sidecar =>
      File('${directory.path}/$_archiveName.sha256').readAsStringSync();

  Future<void> run() => attachArchive(
    tag: 'v1.1.0',
    tagObject: fixtureTagObject,
    commit: fixtureCommit,
    platform: platform,
    outputDirectory: directory.path,
    pollDelay: Duration.zero,
    pollTries: 3,
    run: fakeGh({
      ...fixturePushed,
      fixtureListing: listing(
        listed ??
            [
              releaseJson(
                assets: [
                  ..._draftAssets(_infoSha256),
                  ...?alreadyHeld?.call(sha256, sidecarSha256),
                ],
              ),
            ],
      ),
      fixtureAsset(fixtureAssetId('build_info.json')): ghResult(
        0,
        stdout: releaseInfo,
      ),
      'release upload': ghResult(0),
      fixtureById: alreadyHeld == null
          ? _readBack
          : releaseWith([
              ..._draftAssets(_infoSha256),
              ...alreadyHeld!(sha256, sidecarSha256),
            ]),
      ...extra,
    }, calls),
  );

  Iterable<String> get steps => calls.map((call) => call.take(2).join(' '));
}

Future<void> _refuses(_Attach attach, String message) =>
    check(attach.run()).throws<PublishException>(
      (it) => it.has((e) => e.message, 'message').contains(message),
    );

void main() {
  late Directory directory;

  setUp(() => directory = Directory.systemTemp.createTempSync('attach_test'));
  tearDown(() => directory.deleteSync(recursive: true));

  test('uploads the archive and its sha256 to the draft, and reads them '
      'back', () async {
    final attach = _Attach(directory);

    await attach.run();

    check(attach.steps).deepEquals([
      fixtureRef,
      fixtureTag,
      fixtureListing,
      fixtureAsset(fixtureAssetId('build_info.json')),
      'release upload',
      fixtureRef,
      fixtureTag,
      fixtureById,
    ]);
    check(attach.calls[4]).deepEquals([
      'release',
      'upload',
      'v1.1.0',
      '--repo',
      releaseRepository,
      '${directory.path}/$_archiveName',
      '${directory.path}/$_archiveName.sha256',
    ]);
    check(
      attach.calls.expand((call) => call),
    ).not((it) => it.contains('--clobber'));
  });

  test('is not stopped by the releases of other tags', () async {
    final attach = _Attach(directory);
    final other = _Attach(
      directory,
      listed: [
        releaseJson(tag: 'v1.0.0', draft: false, id: 5),
        releaseJson(
          tag: 'v1.2.0',
          id: 6,
          assets: [assetJson(_archiveName, 'ee')],
        ),
        releaseJson(assets: _draftAssets(attach._infoSha256)),
      ],
    );

    await other.run();
  });

  group('is idempotent', () {
    test('when both assets are already attached with the local digests, '
        'uploading nothing', () async {
      final attach = _Attach(
        directory,
        alreadyHeld: (a, s) => [
          assetJson(_archiveName, a),
          assetJson('$_archiveName.sha256', s),
        ],
      );

      await attach.run();

      check(attach.steps).not((it) => it.contains('release upload'));
      check(attach.steps.last).equals(fixtureTag);
    });

    test('when GitHub has not yet computed a digest, waiting for it', () async {
      final attach = _Attach(
        directory,
        alreadyHeld: (a, s) => [
          assetJson(_archiveName, a),
          assetJson('$_archiveName.sha256', null),
        ],
      );
      final settled = attach.releaseWith([
        ..._draftAssets(attach._infoSha256),
        ...attach.ownAssets,
      ]);

      await _Attach(
        directory,
        alreadyHeld: (a, s) => [
          assetJson(_archiveName, a),
          assetJson('$_archiveName.sha256', null),
        ],
        extra: {fixtureById: settled},
      ).run();
    });

    test('but not when a digest stays uncomputed', () {
      return _refuses(
        _Attach(
          directory,
          alreadyHeld: (a, s) => [
            assetJson(_archiveName, a),
            assetJson('$_archiveName.sha256', null),
          ],
        ),
        'gh release delete-asset v1.1.0 $_archiveName.sha256 --repo '
        '$releaseRepository',
      );
    });
  });

  test('tolerates another platform attaching while it uploads', () async {
    await _Attach(
      directory,
      afterUpload: (assets) => [
        ...assets,
        assetJson('grammars-windows-x64.tar.gz', 'w1'),
        assetJson('grammars-windows-x64.tar.gz.sha256', 'w2'),
      ],
    ).run();
  });

  test('refuses a .tar.gz of this platform it did not upload', () {
    return _refuses(
      _Attach(
        directory,
        afterUpload: (assets) => [
          ...assets,
          assetJson('grammars-linux-arm64.dry-run.tar.gz', 'w1'),
        ],
      ),
      'reading back: grammars-linux-arm64.dry-run.tar.gz is an asset nobody '
      'uploaded',
    );
  });

  test('waits for the digest of what it uploaded', () async {
    final attach = _Attach(directory);
    final pending = attach.releaseWith([
      ..._draftAssets(attach._infoSha256),
      assetJson(_archiveName, null),
      assetJson('$_archiveName.sha256', null),
    ]);

    await _Attach(
      directory,
      extra: {
        fixtureById: [pending, attach._readBack],
      },
    ).run();
  });

  test('refuses an upload whose digest never arrives', () {
    return _refuses(
      _Attach(
        directory,
        afterUpload: (assets) => [
          for (final asset in assets)
            asset['name'] == _archiveName
                ? assetJson(_archiveName, null)
                : asset,
        ],
      ),
      'reading back: $_archiveName: GitHub reports null',
    );
  });

  test('refuses an upload GitHub leaves in a state other than uploaded', () {
    return _refuses(
      _Attach(
        directory,
        afterUpload: (assets) => [
          for (final asset in assets)
            asset['name'] == _archiveName
                ? assetJson(
                    _archiveName,
                    (asset['digest']! as String).substring(7),
                    state: 'open',
                  )
                : asset,
        ],
      ),
      'reading back: $_archiveName is in the state open',
    );
  });

  test('refuses an output directory whose path holds #, which gh reads as a '
      'label', () async {
    final labelled = Directory('${directory.path}/a#b')..createSync();
    final attach = _Attach(labelled);

    await _refuses(attach, 'checking the archive: ${labelled.path} holds #');
    check(attach.calls).isEmpty();
  });

  for (final (label, sidecar) in [
    ('no trailing newline', (String sha, String name) => '$sha  $name'),
    ('two trailing newlines', (String sha, String name) => '$sha  $name\n\n'),
    ('a CRLF', (String sha, String name) => '$sha  $name\r\n'),
    ('one space', (String sha, String name) => '$sha $name\n'),
    (
      'uppercase hex',
      (String sha, String name) => '${sha.toUpperCase()}  $name\n',
    ),
  ]) {
    test('refuses a .sha256 with $label', () {
      return _refuses(
        _Attach(directory, sidecar: sidecar),
        'checking the archive: $_archiveName.sha256 holds',
      );
    });
  }

  group('refuses, uploading nothing,', () {
    Future<void> refuses(
      String label,
      _Attach Function(Directory) attach,
      String message,
    ) async {
      final scenario = attach(directory);
      await _refuses(scenario, message);
      check(scenario.steps).not((it) => it.contains('release upload'));
    }

    test('on macOS, whose assets the draft is created with', () {
      return refuses(
        'macOS',
        (d) => _Attach(d, platform: BuildPlatform.macosArm64),
        'macOS',
      );
    });

    test('a .sha256 that is not the archive\'s', () {
      return refuses(
        'sidecar',
        (d) => _Attach(d, sidecar: (_, name) => '${'0' * 64}  $name\n'),
        'checking the archive: $_archiveName.sha256 holds',
      );
    });

    test('an archive built for another release', () {
      return refuses(
        'release',
        (d) => _Attach(
          d,
          embedded: buildInfoJson(
            platform: 'linux-arm64',
            glibc: '2.17',
            release: 'v1.0.0',
          ),
        ),
        'checking the archive: its build_info.json records the release '
            'v1.0.0, not v1.1.0',
      );
    });

    test('an archive built from another commit', () {
      return refuses(
        'commit',
        (d) => _Attach(
          d,
          embedded: buildInfoJson(
            platform: 'linux-arm64',
            glibc: '2.17',
            commit: fixtureOtherCommit,
          ),
        ),
        'records the commit $fixtureOtherCommit, not $fixtureCommit',
      );
    });

    test('an archive built for another platform', () {
      return refuses(
        'platform',
        (d) => _Attach(d, embedded: buildInfoJson(platform: 'windows-x64')),
        'records the platform windows-x64, not linux-arm64',
      );
    });

    test('a tag not pushed', () {
      return refuses(
        'tag',
        (d) => _Attach(
          d,
          extra: {fixtureRef: ghResult(1, stderr: 'gh: Not Found (HTTP 404)')},
        ),
        'before attaching, GitHub could not resolve v1.1.0',
      );
    });

    test('a draft that does not exist', () {
      return refuses(
        'missing',
        (d) => _Attach(d, listed: const []),
        'finding the draft: no release of v1.1.0',
      );
    });

    test('a release that is published', () {
      return refuses(
        'published',
        (d) => _Attach(d, listed: [releaseJson(draft: false)]),
        'finding the draft: v1.1.0 is not a draft',
      );
    });

    test('a release GitHub reports as immutable', () {
      return refuses(
        'immutable',
        (d) => _Attach(d, listed: [releaseJson(immutable: true)]),
        'finding the draft: v1.1.0 is immutable',
      );
    });

    test('two releases of the tag', () {
      return refuses(
        'two',
        (d) => _Attach(d, listed: [releaseJson(), releaseJson(id: 78)]),
        'finding the draft: 2 releases',
      );
    });

    test('a draft targeting a branch', () {
      return refuses(
        'branch',
        (d) => _Attach(d, listed: [releaseJson(target: 'main')]),
        'finding the draft: v1.1.0 targets main, not $fixtureCommit',
      );
    });

    test('a draft targeting another commit', () {
      return refuses(
        'target',
        (d) => _Attach(d, listed: [releaseJson(target: fixtureOtherCommit)]),
        'finding the draft: v1.1.0 targets $fixtureOtherCommit, not '
            '$fixtureCommit',
      );
    });

    for (final name in [_archiveName, '$_archiveName.sha256']) {
      final remedy =
          'gh release delete-asset v1.1.0 $name --repo $releaseRepository';

      test('a draft that holds $name with another digest', () {
        return refuses(
          'present',
          (d) => _Attach(d, alreadyHeld: (_, _) => [assetJson(name, 'ee')]),
          'finding the draft: v1.1.0 holds $name, which is not the local '
              'file, complete with its digest; remove it with $remedy',
        );
      });

      test('a draft that holds $name in a state other than uploaded', () {
        return refuses(
          'state',
          (d) => _Attach(
            d,
            alreadyHeld: (archive, sidecar) => [
              assetJson(
                name,
                name == _archiveName ? archive : sidecar,
                state: 'starter',
              ),
            ],
          ),
          'remove it with $remedy',
        );
      });

      test('a draft that holds only $name, the other asset missing', () {
        return refuses(
          'partial',
          (d) => _Attach(
            d,
            alreadyHeld: (archive, sidecar) => [
              assetJson(name, name == _archiveName ? archive : sidecar),
            ],
          ),
          'remove it with $remedy',
        );
      });
    }

    test('a draft that holds both assets, one with another digest, names '
        'each one to delete', () async {
      final attach = _Attach(
        directory,
        alreadyHeld: (archive, sidecar) => [
          assetJson(_archiveName, archive),
          assetJson('$_archiveName.sha256', 'ee'),
        ],
      );

      await _refuses(attach, '$_archiveName.sha256 --repo $releaseRepository');
      check(attach.steps).not((it) => it.contains('release upload'));
    });

    test('a draft without a build_info.json', () {
      return refuses(
        'no info',
        (d) => _Attach(d, listed: [releaseJson()]),
        "finding the draft: v1.1.0 has no build_info.json",
      );
    });

    test('an archive whose sources differ from the release\'s', () {
      return refuses(
        'sources',
        (d) => _Attach(
          d,
          embedded: buildInfoJson(
            platform: 'linux-arm64',
            glibc: '2.17',
            sources: {'tree-sitter': 'bb', 'latex': 'ff'},
          ),
        ),
        'checking the sources: latex',
      );
    });

    test('an archive whose generated sources differ from the release\'s', () {
      return refuses(
        'generated',
        (d) => _Attach(
          d,
          embedded: buildInfoJson(
            platform: 'linux-arm64',
            glibc: '2.17',
            generated: {'swift': 'ff'},
          ),
        ),
        'checking the sources: swift',
      );
    });

    test('an archive that names a bundle the release lacks', () {
      return refuses(
        'extra',
        (d) => _Attach(
          d,
          embedded: buildInfoJson(
            platform: 'linux-arm64',
            glibc: '2.17',
            sources: {'tree-sitter': 'bb', 'latex': 'b2', 'zig': 'aa'},
          ),
        ),
        'checking the sources: zig',
      );
    });
  });

  test('fails when the upload fails', () async {
    final attach = _Attach(
      directory,
      extra: {'release upload': ghResult(1, stderr: 'HTTP 422')},
    );

    await _refuses(
      attach,
      'uploading: gh release upload v1.1.0 failed: HTTP 422',
    );
  });

  test('fails when the tag moves during the upload', () async {
    final attach = _Attach(
      directory,
      extra: {
        fixtureTag: [
          ghResult(0, stdout: 'commit $fixtureCommit\n'),
          ghResult(0, stdout: 'commit $fixtureOtherCommit\n'),
        ],
      },
    );

    await _refuses(attach, 'after attaching, v1.1.0 on GitHub names commit');
  });

  group('fails reading back', () {
    Future<void> failsWith(
      List<Map<String, Object?>> Function(List<Map<String, Object?>>) change,
      String message,
    ) => _refuses(_Attach(directory, afterUpload: change), message);

    Map<String, Object?> withDigest(Map<String, Object?> asset, String? d) => {
      for (final MapEntry(:key, :value) in asset.entries)
        if (key != 'digest') key: value,
      'digest': ?d,
    };

    test('an archive with another digest', () {
      return failsWith(
        (assets) => [
          for (final asset in assets)
            asset['name'] == _archiveName
                ? withDigest(asset, 'sha256:ab')
                : asset,
        ],
        'reading back: $_archiveName: GitHub reports sha256:ab',
      );
    });

    test('a .sha256 with no digest', () {
      return failsWith(
        (assets) => [
          for (final asset in assets)
            asset['name'] == '$_archiveName.sha256'
                ? withDigest(asset, null)
                : asset,
        ],
        'reading back: $_archiveName.sha256: GitHub reports null',
      );
    });

    test('an asset that existed before, changed', () {
      return failsWith(
        (assets) => [
          for (final asset in assets)
            asset['name'] == _macosAssets[0]
                ? withDigest(asset, 'sha256:changed')
                : asset,
        ],
        'reading back: ${_macosAssets[0]} was sha256:dd, GitHub reports '
        'sha256:changed',
      );
    });

    test('an asset that existed before, gone', () {
      return failsWith(
        (assets) => [
          for (final asset in assets)
            if (asset['name'] != _macosAssets[1]) asset,
        ],
        'reading back: ${_macosAssets[1]} is gone',
      );
    });

    test('an asset nobody uploaded', () {
      return failsWith(
        (assets) => [...assets, assetJson('stray.bin', 'ab')],
        'reading back: stray.bin',
      );
    });
  });

  group('the --sources build_info.json', () {
    void write(Map<String, Object?> info) => File(
      '${directory.path}/build_info.json',
    ).writeAsStringSync(jsonEncode(info));

    test('of the release and commit is accepted', () {
      write(buildInfoJson());

      requireSourcesRecord(directory.path, 'v1.1.0', fixtureCommit);
    });

    for (final (label, info, message) in [
      (
        'another release',
        buildInfoJson(release: 'v1.0.0'),
        'records the release v1.0.0, not v1.1.0',
      ),
      (
        'no release',
        buildInfoJson(release: null),
        'records the release null, not v1.1.0',
      ),
      (
        'another commit',
        buildInfoJson(commit: fixtureOtherCommit),
        'records the commit $fixtureOtherCommit, not $fixtureCommit',
      ),
      (
        'no commit',
        {...buildInfoJson(), 'repository': null},
        'records the commit null, not $fixtureCommit',
      ),
    ]) {
      test('naming $label is refused', () {
        write(info);

        check(
            () => requireSourcesRecord(directory.path, 'v1.1.0', fixtureCommit),
          ).throws<PublishException>().has((e) => e.message, 'message')
          ..contains('checking --sources')
          ..contains(message);
      });
    }

    test('missing is refused', () {
      check(() => requireSourcesRecord(directory.path, 'v1.1.0', fixtureCommit))
          .throws<PublishException>()
          .has((e) => e.message, 'message')
          .contains(
            'checking --sources: ${directory.path} holds no build_info.json',
          );
    });

    test('that is not JSON is refused', () {
      File('${directory.path}/build_info.json').writeAsStringSync('[');

      check(() => requireSourcesRecord(directory.path, 'v1.1.0', fixtureCommit))
          .throws<PublishException>()
          .has((e) => e.message, 'message')
          .contains('checking --sources');
    });
  });
}
