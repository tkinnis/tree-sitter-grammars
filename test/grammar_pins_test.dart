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

  test('an entry with patches, and only one, records patchedSha256', () {
    Map<String, Object?> entry(String name, Map<String, Object?> fields) => {
      'url': 'https://github.com/a/$name',
      'commit': _sha,
      'filesSha256': _files,
      'license': 'MIT',
      ...fields,
    };
    final problems = pinProblems([
      entry('tree-sitter-a', {
        'patches': ['patches/tree-sitter-a/fix.patch'],
      }),
      entry('tree-sitter-b', {'patchedSha256': _files}),
      entry('tree-sitter-c', {
        'patches': ['patches/tree-sitter-other/fix.patch'],
        'patchedSha256': _files,
      }),
      entry('tree-sitter-d', {
        'patches': [
          'patches/tree-sitter-d/fix.patch',
          'patches/tree-sitter-d/fix.patch',
        ],
        'patchedSha256': _files,
      }),
      entry('tree-sitter-e', {'patches': const [], 'patchedSha256': _files}),
      entry('tree-sitter-f', {
        'patches': ['patches/tree-sitter-f/fix.patch'],
        'patchedSha256': _files,
      }),
    ]);

    check(problems).deepEquals([
      'tree-sitter-a: an entry with patches records the patchedSha256 of '
          'the tree they leave, 64 lowercase hex digits',
      'tree-sitter-b: patchedSha256 belongs only to an entry that lists '
          'patches',
      'tree-sitter-c: patches must be a list of paths '
          'patches/tree-sitter-c/<name>.patch',
      'tree-sitter-d: patches lists one patch twice',
      'tree-sitter-e: patches must be a list of paths '
          'patches/tree-sitter-e/<name>.patch',
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

  test('withPin keeps the patches and records only the patchedSha256 '
      'given', () {
    final entry = <String, Object?>{
      'url': 'https://github.com/a/tree-sitter-a',
      'commit': _other,
      'filesSha256': _files,
      'license': 'MIT',
      'patches': ['patches/tree-sitter-a/fix.patch'],
      'patchedSha256': _files,
    };
    const patched =
        'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';

    final moved = withPin(entry, _sha, filesSha256: _files);
    check(moved['patches']).equals(entry['patches']);
    check(moved).not((it) => it.containsKey('patchedSha256'));
    check(pinProblems([moved])).isNotEmpty();
    check(
      withPin(entry, _sha, filesSha256: _files, patchedSha256: patched),
    ).has((it) => it['patchedSha256'], 'patchedSha256').equals(patched);
    check(
      () => withPin(entry, _sha, filesSha256: _files, patchedSha256: 'short'),
    ).throws<PinException>();
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

  group('checkoutMove', () {
    late Directory temporary;
    late String url;
    late String checkout;
    late String first;
    late String second;
    late String third;
    late String aside;

    setUpAll(() async {
      temporary = Directory.systemTemp.createTempSync('checkout_move');
      final upstream = await FixtureRepository.create(
        p.join(temporary.path, 'tree-sitter-x'),
      );
      url = upstream.path;
      first = await upstream.commit({'grammar.js': bytes('1')});
      second = await upstream.commit({'grammar.js': bytes('2')});
      third = await upstream.commit({'grammar.js': bytes('3')});
      await upstream.git(['checkout', '--quiet', '-b', 'other', first]);
      aside = await upstream.commit({'grammar.js': bytes('aside')});
      await upstream.git(['checkout', '--quiet', 'main']);
      checkout = p.join(temporary.path, 'checkout');
      await fixtureGit(temporary.path, ['clone', '--quiet', url, checkout]);
    });

    tearDownAll(() => temporary.deleteSync(recursive: true));

    Future<CheckoutMove> move(String head, Map<String, Object?> pin) async {
      await fixtureGit(checkout, ['checkout', '--quiet', '--detach', head]);
      return checkoutMove(runGit, checkout, {'url': url, ...pin});
    }

    test('moves a pin forward to a HEAD that contains it', () async {
      check(
        await move(third, {'commit': first}),
      ).equals((moveTo: third, kept: null));
    });

    test('leaves a pin that is HEAD as it is', () async {
      check(
        await move(second, {'commit': second}),
      ).equals((moveTo: null, kept: null));
    });

    test('keeps a pin chosen ahead of the checkout', () async {
      final (:moveTo, :kept) = await move(first, {'commit': third});

      check(moveTo).isNull();
      check(kept).isNotNull().contains(
        "kept at $third, which its checkout's HEAD $first does not contain",
      );
    });

    test('keeps a pin on another line of history', () async {
      final (:moveTo, :kept) = await move(third, {'commit': aside});

      check(moveTo).isNull();
      check(kept).isNotNull().contains('kept at $aside');
    });

    test('keeps a deploy pin, naming the --set that moves it', () async {
      final (:moveTo, :kept) = await move(third, {
        'commit': aside,
        'sourceCommit': first,
      });

      check(moveTo).isNull();
      check(kept).isNotNull()
        ..contains('kept at its deploy pin $aside, deployed from $first')
        ..contains('--source-commit=');
    });

    test('refuses a pin the store does not hold', () async {
      await check(move(third, {'commit': '1' * 40})).throws<PinException>(
        (it) => it
            .has((e) => e.message, 'message')
            .contains('cannot tell whether HEAD $third contains the pin'),
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
