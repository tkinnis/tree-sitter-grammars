import 'dart:io';

import 'package:checks/checks.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../tool/src/git.dart';
import '../tool/src/grammar_pins.dart';
import 'support/git_fixture.dart';

const _sha = '0123456789abcdef0123456789abcdef01234567';
const _other = 'fedcba9876543210fedcba9876543210fedcba98';
const _files =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

/// Answers git commands from a table keyed by the joined arguments.
Future<String> Function(String, List<String>) _fakeGit(
  Map<String, String> answers,
) =>
    (directory, arguments) async =>
        answers[arguments.join(' ')] ??
        (throw StateError('unexpected git ${arguments.join(' ')}'));

void main() {
  test('the committed grammars.json is fully pinned', () {
    final entries = parseGrammars(
      File('tool/grammars.json').readAsStringSync(),
    );

    check(pinProblems(entries)).isEmpty();
    check(entries.where((entry) => entry['url'] != null)).length.equals(46);
  });

  test('an unpinned, unlicensed or abbreviated entry is reported', () {
    final problems = pinProblems([
      {
        'url': 'https://github.com/a/tree-sitter-a',
        'filesSha256': _files,
        'license': 'MIT',
      },
      {
        'url': 'https://github.com/b/tree-sitter-b',
        'commit': _sha,
        'filesSha256': _files,
      },
      {
        'url': 'https://github.com/c/tree-sitter-c',
        'commit': _sha.substring(0, 12),
        'filesSha256': _files.substring(0, 40),
        'license': 'MIT',
        'sourceCommit': 'deploy',
      },
      {'name': 'plaintext', 'noop': true},
    ]);

    check(problems).deepEquals([
      'tree-sitter-a: commit must be 40 lowercase hex digits',
      "tree-sitter-b: license must name the grammar's licence",
      'tree-sitter-c: commit must be 40 lowercase hex digits',
      'tree-sitter-c: filesSha256 must be 64 lowercase hex digits',
      'tree-sitter-c: sourceCommit must be 40 lowercase hex digits',
    ]);
  });

  test('a generated grammar and only one records generatedSha256', () {
    final problems = pinProblems([
      {
        'url': 'https://github.com/a/tree-sitter-a',
        'commit': _sha,
        'filesSha256': _files,
        'license': 'MIT',
        'generate': true,
      },
      {
        'url': 'https://github.com/b/tree-sitter-b',
        'commit': _sha,
        'filesSha256': _files,
        'license': 'MIT',
        'generatedSha256': _files,
      },
      {
        'url': 'https://github.com/c/tree-sitter-c',
        'commit': _sha,
        'filesSha256': _files,
        'license': 'MIT',
        'generate': true,
        'generatedSha256': _files,
      },
    ]);

    check(problems).deepEquals([
      "tree-sitter-a: a generated grammar's generatedSha256 must be 64 "
          'lowercase hex digits',
      'tree-sitter-b: generatedSha256 belongs only to a generated grammar',
    ]);
  });

  test('two spellings of one repository are listed more than once', () {
    final problems = pinProblems([
      {
        'url': 'https://github.com/a/tree-sitter-a',
        'commit': _sha,
        'filesSha256': _files,
        'license': 'MIT',
      },
      {
        'url': 'https://github.com/a/tree-sitter-a.git/',
        'commit': _sha,
        'filesSha256': _files,
        'license': 'MIT',
      },
    ]);

    check(problems).deepEquals(['tree-sitter-a: listed more than once']);
  });

  test('pin fields follow url, and other fields keep their order', () {
    final json = encodeGrammars([
      {
        'url': 'https://github.com/a/tree-sitter-a',
        'highlights': 'queries/highlights.scm',
        'license': 'MIT',
        'filesSha256': _files,
        'commit': _sha,
      },
    ]);

    check(json).equals(
      '[\n'
      '  {\n'
      '    "url": "https://github.com/a/tree-sitter-a",\n'
      '    "commit": "$_sha",\n'
      '    "filesSha256": "$_files",\n'
      '    "license": "MIT",\n'
      '    "highlights": "queries/highlights.scm"\n'
      '  }\n'
      ']\n',
    );
  });

  test('a new pin drops the sourceCommit of the one it replaces', () {
    final entry = {
      'url': 'https://github.com/a/tree-sitter-a',
      'commit': _other,
      'sourceCommit': _other,
    };

    check(withPin(entry, _sha, filesSha256: _files))
      ..has((pinned) => pinned['commit'], 'commit').equals(_sha)
      ..has((pinned) => pinned['filesSha256'], 'filesSha256').equals(_files)
      ..has(
        (pinned) => pinned.containsKey('sourceCommit'),
        'has sourceCommit',
      ).isFalse();
    check(
      withPin(
        entry,
        _sha,
        filesSha256: _files,
        sourceCommit: _sha,
      )['sourceCommit'],
    ).equals(_sha);
    check(
      withPin({...entry, 'generatedSha256': _files}, _sha, filesSha256: _files),
    ).not((it) => it.containsKey('generatedSha256'));
  });

  group('pinFromCheckout', () {
    const url = 'https://github.com/tree-sitter/tree-sitter-ocaml';

    test(
      'pins HEAD when origin matches and a remote branch contains it',
      () async {
        final git = _fakeGit({
          'remote get-url origin': '$url.git\n',
          'rev-parse HEAD': '$_sha\n',
          'branch -r --contains $_sha --list origin/*': '  origin/master\n',
        });

        check(await pinFromCheckout(git, 'grammars/x', url)).equals(_sha);
      },
    );

    test('refuses a checkout whose origin is another repository', () async {
      final git = _fakeGit({
        'remote get-url origin': 'https://github.com/someone/fork\n',
      });

      await check(pinFromCheckout(git, 'grammars/x', url)).throws<PinException>(
        (it) => it
            .has((e) => e.message, 'message')
            .contains('origin is https://github.com/someone/fork'),
      );
    });

    test('refuses a HEAD that no branch on origin contains', () async {
      final git = _fakeGit({
        'remote get-url origin': url,
        'rev-parse HEAD': _sha,
        'branch -r --contains $_sha --list origin/*': '',
      });

      await check(pinFromCheckout(git, 'grammars/x', url)).throws<PinException>(
        (it) => it
            .has((e) => e.message, 'message')
            .equals('tree-sitter-ocaml: no branch on origin contains $_sha'),
      );
    });
  });

  group('requireOnOrigin', () {
    late Directory temporary;
    late String store;
    late String onOrigin;
    late String onForkOnly;

    setUpAll(() async {
      temporary = Directory.systemTemp.createTempSync('pins_test');
      final upstream = await FixtureRepository.create(
        p.join(temporary.path, 'upstream'),
      );
      onOrigin = await upstream.commit({'grammar.js': bytes('a')});
      final fork = await FixtureRepository.create(
        p.join(temporary.path, 'fork'),
      );
      await fork.git(['pull', '--quiet', upstream.path, 'main']);
      onForkOnly = await fork.commit({'grammar.js': bytes('b')});
      store = (await FixtureRepository.create(
        p.join(temporary.path, 'store'),
      )).path;
      await fixtureGit(store, ['remote', 'add', 'origin', upstream.path]);
      await fixtureGit(store, ['remote', 'add', 'fork', fork.path]);
      await fixtureGit(store, ['fetch', '--quiet', '--all']);
    });

    tearDownAll(() => temporary.deleteSync(recursive: true));

    test('accepts a commit an origin branch contains', () async {
      await requireOnOrigin(runGit, store, onOrigin, 'tree-sitter-x');
    });

    test('refuses a commit that only another remote contains', () async {
      await check(
        requireOnOrigin(runGit, store, onForkOnly, 'tree-sitter-x'),
      ).throws<PinException>(
        (it) => it
            .has((e) => e.message, 'message')
            .equals('tree-sitter-x: no branch on origin contains $onForkOnly'),
      );
    });
  });
}
