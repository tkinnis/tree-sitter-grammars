import 'dart:convert';
import 'dart:io';

import 'package:checks/checks.dart';
import 'package:test/test.dart';

import '../tool/src/publish.dart';

const _archive = '/out/grammars-macos-arm64.tar.gz';
const _bundle = '/out/sources/tree-sitter-0000.tar.gz';
const _assets = {_archive: 'aa', _bundle: 'bb'};
const _tagObject = '1111111111111111111111111111111111111111';
const _commit = '2222222222222222222222222222222222222222';
const _other = '3333333333333333333333333333333333333333';
const _ref = 'api repos/$releaseRepository/git/ref/tags/v1.1.0';
const _tag = 'api repos/$releaseRepository/git/tags/$_tagObject';

/// Answers `gh` by its first two arguments from [answers], a result or a
/// list of results given in turn (the last one repeating), recording every
/// call in [calls].
ProcessRunner _gh(Map<String, Object> answers, List<List<String>> calls) {
  final given = <String, int>{};
  return (executable, arguments) async {
    check(executable).equals('gh');
    calls.add(arguments);
    final key = arguments.take(2).join(' ');
    return switch (answers[key]) {
      final ProcessResult result => result,
      final List<ProcessResult> results =>
        results[(given[key] = (given[key] ?? -1) + 1).clamp(
          0,
          results.length - 1,
        )],
      _ => throw StateError('unexpected gh ${arguments.join(' ')}'),
    };
  };
}

/// The tag resolutions of a pushed annotated tag [_tagObject] naming
/// [_commit].
final _pushed = {
  _ref: _result(0, stdout: 'tag $_tagObject\n'),
  _tag: _result(0, stdout: 'commit $_commit\n'),
};

Future<void> _publish(
  Map<String, Object> answers, [
  List<List<String>>? calls,
]) => publishRelease(
  tag: 'v1.1.0',
  tagObject: _tagObject,
  commit: _commit,
  assets: _assets,
  notesFile: '/out/release-notes.md',
  run: _gh(answers, calls ?? []),
);

final _published = _result(
  0,
  stdout: jsonEncode({
    'id': _draftId,
    'assets': jsonDecode(
      _digests({
        'grammars-macos-arm64.tar.gz': 'aa',
        'tree-sitter-0000.tar.gz': 'bb',
      }),
    ),
  }),
);

/// The listing of the repository's releases, one page, holding [releases].
ProcessResult _releases(List<Map<String, Object?>> releases) =>
    _result(0, stdout: jsonEncode([releases]));

/// The listing after the draft [_draftId] of v1.1.0 exists.
final _listed = _releases([
  {'id': _draftId, 'tag_name': 'v1.1.0', 'draft': true},
]);

const _draftId = 77;
const _listing = 'api repos/$releaseRepository/releases?per_page=100';
const _byId = 'api repos/$releaseRepository/releases/$_draftId';

ProcessResult _result(int exitCode, {String stdout = '', String stderr = ''}) =>
    ProcessResult(0, exitCode, stdout, stderr);

final _noReleases = _releases([]);

String _digests(Map<String, String> digests) => jsonEncode([
  for (final MapEntry(:key, :value) in digests.entries)
    {'name': key, 'digest': 'sha256:$value'},
]);

void main() {
  test('creates a draft from the pushed tag with every asset', () async {
    final calls = <List<String>>[];

    await _publish({
      _listing: [_noReleases, _listed],
      ..._pushed,
      'release create': _result(0),
      _byId: _published,
    }, calls);

    check([for (final call in calls) call.take(2).join(' ')]).deepEquals([
      _listing,
      _ref,
      _tag,
      'release create',
      _ref,
      _tag,
      _listing,
      _byId,
    ]);
    check(calls[3]).deepEquals([
      'release',
      'create',
      'v1.1.0',
      '--repo',
      releaseRepository,
      '--draft',
      '--target',
      _commit,
      '--verify-tag',
      '--title',
      'v1.1.0',
      '--notes-file',
      '/out/release-notes.md',
      _archive,
      _bundle,
    ]);
    check(calls.expand((call) => call)).not((it) => it.contains('--clobber'));
  });

  for (final (label, draft) in [('published', false), ('draft', true)]) {
    test('refuses a $label release of the tag, creating nothing', () async {
      final calls = <List<String>>[];

      await check(
        _publish({
          _listing: _releases([
            {'id': 1, 'tag_name': 'v1.0.0', 'draft': false},
            {'id': 2, 'tag_name': 'v1.1.0', 'draft': draft},
          ]),
        }, calls),
      ).throws<PublishException>(
        (it) => it.has((e) => e.message, 'message').contains('exists'),
      );
      check(calls).length.equals(1);
    });
  }

  test('is not stopped by the releases of other tags', () async {
    final other = {'id': 1, 'tag_name': 'v1.0.0', 'draft': false};

    await _publish({
      _listing: [
        _releases([other]),
        _releases([
          other,
          {'id': _draftId, 'tag_name': 'v1.1.0', 'draft': true},
        ]),
      ],
      ..._pushed,
      'release create': _result(0),
      _byId: _published,
    });
  });

  for (final (label, after) in [
    ('none', <Map<String, Object?>>[]),
    (
      'two',
      [
        {'id': _draftId, 'tag_name': 'v1.1.0', 'draft': true},
        {'id': 78, 'tag_name': 'v1.1.0', 'draft': true},
      ],
    ),
  ]) {
    test('refuses to read back when GitHub lists $label releases of the '
        'tag it created', () async {
      await check(
        _publish({
          _listing: [_noReleases, _releases(after)],
          ..._pushed,
          'release create': _result(0),
          _byId: _published,
        }),
      ).throws<PublishException>(
        (it) => it
            .has((e) => e.message, 'message')
            .contains('GitHub lists ${after.length} releases'),
      );
    });
  }

  test('lists every page of the releases, and finds the tag on a later '
      'one', () async {
    final calls = <List<String>>[];

    await check(
      _publish({
        _listing: _result(
          0,
          stdout: jsonEncode([
            [
              {'id': 1, 'tag_name': 'v1.0.0', 'draft': false},
            ],
            [
              {'id': 2, 'tag_name': 'v1.1.0', 'draft': true},
            ],
          ]),
        ),
      }, calls),
    ).throws<PublishException>(
      (it) => it.has((e) => e.message, 'message').contains('exists'),
    );
    check(calls.single).containsEqualInOrder(['--paginate', '--slurp']);
  });

  test('stops when gh cannot list the releases', () async {
    await check(
      _publish({_listing: _result(1, stderr: 'HTTP 401: Bad credentials')}),
    ).throws<PublishException>(
      (it) => it.has((e) => e.message, 'message').contains('401'),
    );
  });

  for (final (label, answers, expected) in [
    (
      'a tag not pushed',
      {_ref: _result(1, stderr: 'gh: Not Found (HTTP 404)')},
      'push it with git push origin v1.1.0',
    ),
    (
      'a lightweight tag',
      {_ref: _result(0, stdout: 'commit $_commit\n')},
      'is a lightweight tag',
    ),
    (
      'a tag re-created after the push',
      {_ref: _result(0, stdout: 'tag $_other\n')},
      'is the tag object $_other, not the local tag $_tagObject',
    ),
    (
      'a tag naming another commit',
      {..._pushed, _tag: _result(0, stdout: 'commit $_other\n')},
      'names commit $_other, not the built commit $_commit',
    ),
  ]) {
    test('refuses $label on GitHub, creating nothing', () async {
      final calls = <List<String>>[];

      await check(
        _publish({_listing: _noReleases, ...answers}, calls),
      ).throws<PublishException>(
        (it) => it.has((e) => e.message, 'message')
          ..startsWith('before publishing')
          ..contains(expected),
      );
      check(
        calls.map((call) => call.take(2).join(' ')),
      ).not((it) => it.contains('release create'));
    });
  }

  test('fails when the tag moves while the release is created', () async {
    await check(
      _publish({
        _listing: [_noReleases, _listed],
        ..._pushed,
        _tag: [
          _result(0, stdout: 'commit $_commit\n'),
          _result(0, stdout: 'commit $_other\n'),
        ],
        'release create': _result(0),
        _byId: _published,
      }),
    ).throws<PublishException>(
      (it) => it.has((e) => e.message, 'message')
        ..startsWith('after publishing')
        ..contains('names commit $_other'),
    );
  });

  test('refuses an upload GitHub reports with another digest', () async {
    await check(
      _publish({
        _listing: [_noReleases, _listed],
        ..._pushed,
        'release create': _result(0),
        _byId: _result(
          0,
          stdout: jsonEncode({
            'id': _draftId,
            'assets': jsonDecode(
              _digests({
                'grammars-macos-arm64.tar.gz': 'aa',
                'tree-sitter-0000.tar.gz': 'cc',
              }),
            ),
          }),
        ),
      }),
    ).throws<PublishException>(
      (it) => it
          .has((e) => e.message, 'message')
          .contains('tree-sitter-0000.tar.gz: GitHub reports sha256:cc'),
    );
  });

  test('the notes name the runtime, the archive and every bundle', () {
    final notes = releaseNotes({
      'platform': 'macos-arm64',
      'deploymentTarget': '13.0',
      'treeSitter': {'tag': 'v0.27.0', 'commit': 'c0ffee'},
      'sources': {
        'tree-sitter': {
          'commit': 'c0ffee',
          'file': 'sources/tree-sitter-c0ffee.tar.gz',
          'sha256': 'bb',
        },
      },
      'generated': {
        'swift': {
          'commit': 'beef',
          'cli': '0.27.0',
          'file': 'sources/swift-generated-beef.tar.gz',
          'sha256': 'cc',
        },
      },
    }, 'aa');

    check(notes)
      ..contains('tree-sitter v0.27.0 (c0ffee)')
      ..contains('sha256 `aa`')
      ..contains(
        '| tree-sitter | `c0ffee` | `tree-sitter-c0ffee.tar.gz` | `bb` |',
      )
      ..contains(
        '| swift, generated by tree-sitter 0.27.0 | `beef` | '
        '`swift-generated-beef.tar.gz` | `cc` |',
      );
  });

  for (final (label, platform) in [
    ('records none', null),
    ('is garbled', 'macos-arm6'),
    ('is not a platform', 'linux-x64'),
    ('is not a number', 7),
    ('is a Linux build', 'linux-arm64'),
    ('is a Windows build', 'windows-x64'),
  ]) {
    test('the notes refuse a build_info.json whose platform $label', () {
      check(
            () => releaseNotes({
              'platform': ?platform,
              'deploymentTarget': '13.0',
              'treeSitter': {'tag': 'v0.27.0', 'commit': 'c0ffee'},
              'sources': const <String, Object?>{},
            }, 'aa'),
          )
          .throws<PublishException>()
          .has((e) => e.message, 'message')
          .contains('platform');
    });
  }
}
