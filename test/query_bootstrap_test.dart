import 'dart:convert';
import 'dart:io';

import 'package:checks/checks.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../tool/src/git.dart';
import '../tool/src/query_bootstrap.dart';
import '../tool/src/query_headers.dart';
import '../tool/src/query_provenance.dart';
import 'support/git_fixture.dart';

const _oldHighlights = '(identifier) @variable\n';
const _newHighlights = '; inherits: c\n\n(identifier) @variable.member\n';
const _folds = '(block) @fold\n';
const _otherQuery = '(word) @string\n';
const _here = {'origin': 'here', 'changed': false, 'upstream': null};
const _highlightsPath = 'runtime/queries/mylang/highlights.scm';

void main() {
  late Directory temporary;
  late FixtureRepository upstream;
  late String oldCommit;
  late String newCommit;
  late String pullCommit;
  late String legacyCommit;

  setUp(() async {
    temporary = Directory.systemTemp.createTempSync('bootstrap_test');
    upstream = await FixtureRepository.create(
      p.join(temporary.path, 'nvim-treesitter'),
    );
    oldCommit = await upstream.commit({_highlightsPath: bytes(_oldHighlights)});
    newCommit = await upstream.commit({
      _highlightsPath: bytes(_newHighlights),
      'runtime/queries/mylang/folds.scm': bytes(_folds),
      'runtime/queries/mylang/textobjects.scm': bytes('(block) @x\n'),
      'runtime/queries/mylanguage/indents.scm': bytes('(block) @indent\n'),
      'runtime/queries/c_sharp/highlights.scm': bytes('(name) @type\n'),
      'runtime/queries/objectsonly/textobjects.scm': bytes('(block) @x\n'),
      'runtime/queries/latin1/folds.scm': [0x28, 0x62, 0xe9, 0x29, 0x0a],
      'runtime/queries/replacement/folds.scm': bytes(
        '((string) @fold (#eq? @fold "\u{FFFD}"))\n',
      ),
      'runtime/queries/stray/highlights.scm': bytes(
        '; Derived from nvim-treesitter somewhere else\n(a) @b\n',
      ),
    });
    // A commit only a pull request's ref carries, as GitHub serves one.
    await upstream.git(['checkout', '--quiet', '-b', 'proposal']);
    pullCommit = await upstream.commit({
      _highlightsPath: bytes('(x) @proposed\n'),
    });
    await upstream.git(['update-ref', 'refs/pull/1/head', pullCommit]);
    await upstream.git(['checkout', '--quiet', 'main']);
    await upstream.git(['branch', '--quiet', '-D', 'proposal']);
    // A branch kept in the layout before queries moved under runtime/.
    await upstream.git(['checkout', '--quiet', '-b', 'legacy', oldCommit]);
    legacyCommit = await upstream.commit({
      'queries/legacylang/highlights.scm': bytes(_oldHighlights),
    });
    await upstream.git(['checkout', '--quiet', 'main']);
  });

  tearDown(() => temporary.deleteSync(recursive: true));

  String store() => p.join(temporary.path, 'store');

  Future<String> fetch({String? commit}) =>
      fetchNvimCommit(store(), commit: commit, url: upstream.path);

  Future<bool> shallow(String directory) async =>
      await fixtureGit(directory, ['rev-parse', '--is-shallow-repository']) ==
      'true';

  group('fetchNvimCommit', () {
    test('fetches and returns the commit origin HEAD names', () async {
      check(await fetch()).equals(newCommit);
      check(
        await fixtureGit(store(), ['remote', 'get-url', 'origin']),
      ).equals(upstream.path);
    });

    test('keeps a complete store complete', () async {
      await fetch(commit: oldCommit);
      await fetch();

      check(await shallow(store())).isFalse();
    });

    test('fetches a commit a branch of origin contains', () async {
      check(await fetch(commit: oldCommit)).equals(oldCommit);
      check(
        await fixtureGit(store(), ['cat-file', '-t', oldCommit]),
      ).equals('commit');
    });

    test('completes a store an earlier fetch left shallow', () async {
      final url = 'file://${upstream.path}';
      Directory(store()).createSync();
      await fixtureGit(store(), ['init', '--quiet']);
      await fixtureGit(store(), ['remote', 'add', 'origin', url]);
      await fixtureGit(store(), ['fetch', '--quiet', '--depth=1', url, 'main']);
      check(await shallow(store())).isTrue();

      final fetched = await fetchNvimCommit(
        store(),
        commit: oldCommit,
        url: url,
      );

      check(fetched).equals(oldCommit);
      check(await shallow(store())).isFalse();
    });

    test('refuses a commit only a pull request carries', () async {
      await check(fetch(commit: pullCommit)).throws<BootstrapException>(
        (it) => it
            .has((e) => e.message, 'message')
            .equals(
              'nvim-treesitter: no branch on origin contains $pullCommit',
            ),
      );
    });

    test('refuses such a commit when the store already holds it', () async {
      await fetch();
      await fixtureGit(store(), ['fetch', '--quiet', 'origin', pullCommit]);

      await check(fetch(commit: pullCommit)).throws<BootstrapException>();
    });

    test(
      'refuses it when a refspec of the store fetches pull requests',
      () async {
        await fetch();
        await fixtureGit(store(), [
          'config',
          '--add',
          'remote.origin.fetch',
          '+refs/pull/*/head:refs/remotes/origin/pr/*',
        ]);
        await fixtureGit(store(), ['fetch', '--quiet', 'origin']);
        check(
          await fixtureGit(store(), ['rev-parse', 'refs/remotes/origin/pr/1']),
        ).equals(pullCommit);

        await check(fetch(commit: pullCommit)).throws<BootstrapException>();
      },
    );

    test('refuses a commit whose branch origin has deleted', () async {
      await upstream.git(['checkout', '--quiet', '-b', 'topic']);
      final topicCommit = await upstream.commit({
        'runtime/queries/mylang/folds.scm': bytes('(topic) @fold\n'),
      });
      await upstream.git(['checkout', '--quiet', 'main']);
      check(await fetch(commit: topicCommit)).equals(topicCommit);
      await upstream.git(['branch', '--quiet', '-D', 'topic']);

      await check(fetch(commit: topicCommit)).throws<BootstrapException>();
    });

    test('refuses an object that is not a commit', () async {
      final tree = await upstream.git(['rev-parse', '$newCommit^{tree}']);

      await check(fetch(commit: tree)).throws<BootstrapException>(
        (it) => it
            .has((e) => e.message, 'message')
            .equals('nvim-treesitter: $tree is a tree'),
      );
    });

    test('refuses a store of another repository', () async {
      final other = await FixtureRepository.create(store());
      await other.git(['remote', 'add', 'origin', '/elsewhere']);

      await check(fetch()).throws<Exception>(
        (it) => it
            .has((e) => '$e', 'message')
            .contains('origin of ${store()} is /elsewhere, not'),
      );
    });

    for (final key in ['remote.origin.promisor', 'extensions.partialclone']) {
      test('refuses a partial clone, whose $key is set', () async {
        await fetch();
        await fixtureGit(store(), ['config', key, 'origin']);

        await check(fetch()).throws<BootstrapException>(
          (it) => it
              .has((e) => e.message, 'message')
              .startsWith('${store()} is a partial clone ($key is set)'),
        );
      });
    }
  });

  group('importNvimQueries', () {
    Future<List<ImportedQuery>> import(String language, String commit) =>
        importNvimQueries(store: store(), commit: commit, language: language);

    test('reads each imported type at the commit, under its header', () async {
      final commit = await fetch();

      final imports = await import('mylang', commit);

      check(imports.map((query) => query.file).toList()).deepEquals([
        'queries/mylang/highlights.scm',
        'queries/mylang/folds.scm',
      ]);
      check(imports.first.content).equals(
        '; Derived from nvim-treesitter $nvimTreesitterUrl, '
        '$_highlightsPath @ $commit, Apache-2.0.\n'
        '; Unchanged.\n'
        '\n'
        '$_newHighlights',
      );
      check(imports.first.provenance).deepEquals({
        'origin': 'nvim',
        'changed': false,
        'upstream': {
          'repo': nvimTreesitterUrl,
          'commit': commit,
          'path': _highlightsPath,
        },
      });
    });

    test(
      'reads the files of the commit it names, not of a later one',
      () async {
        await fetch(commit: oldCommit);
        check(await fetch()).equals(newCommit);

        final imports = await import('mylang', oldCommit);

        check(imports).length.equals(1);
        check(imports.single.content).endsWith('\n\n$_oldHighlights');
        check(imports.single.content).contains('@ $oldCommit, Apache-2.0.');
      },
    );

    test('reads c-sharp from the directory nvim-treesitter names', () async {
      final commit = await fetch();

      final imports = await import('c-sharp', commit);

      check(imports.single.file).equals('queries/c-sharp/highlights.scm');
      check(
        imports.single.content,
      ).contains('runtime/queries/c_sharp/highlights.scm @ $commit');
    });

    test('refuses a language nvim-treesitter has no directory for', () async {
      final commit = await fetch();

      await check(import('mylan', commit)).throws<BootstrapException>(
        (it) => it
            .has((e) => e.message, 'message')
            .equals(
              'nvim-treesitter has no runtime/queries/mylan/ or '
              'queries/mylan/ at $commit',
            ),
      );
    });

    test('reads a commit from before the queries moved', () async {
      check(await fetch(commit: legacyCommit)).equals(legacyCommit);

      final imports = await import('legacylang', legacyCommit);

      check(imports.single.file).equals('queries/legacylang/highlights.scm');
      check(imports.single.content).startsWith(
        '; Derived from nvim-treesitter $nvimTreesitterUrl, '
        'queries/legacylang/highlights.scm @ $legacyCommit, Apache-2.0.\n',
      );
    });

    test('refuses a directory with none of the imported types', () async {
      final commit = await fetch();

      await check(import('objectsonly', commit)).throws<BootstrapException>(
        (it) => it
            .has((e) => e.message, 'message')
            .startsWith('nvim-treesitter has none of highlights, folds'),
      );
    });

    test('refuses a file that is not UTF-8 text', () async {
      final commit = await fetch();

      await check(import('latin1', commit)).throws<BootstrapException>(
        (it) => it
            .has((e) => e.message, 'message')
            .equals(
              'runtime/queries/latin1/folds.scm at $commit '
              'is not UTF-8 text',
            ),
      );
    });

    test('keeps a replacement character that is UTF-8 text', () async {
      final commit = await fetch();

      final imports = await import('replacement', commit);

      check(imports.single.content).endsWith('"\u{FFFD}"))\n');
    });
  });

  group('bootstrap', () {
    late String root;
    late String provenance;

    setUp(() {
      root = p.join(temporary.path, 'repository');
      provenance = '${jsonEncode({'queries/other/highlights.scm': _here})}\n';
      _write(root, 'queries/other/highlights.scm', _otherQuery);
      _write(root, 'tool/query_provenance.json', provenance);
    });

    BootstrapRequest request({
      String language = 'mylang',
      bool force = false,
      bool dryRun = false,
      String? commit,
    }) => (language: language, commit: commit, force: force, dryRun: dryRun);

    Future<BootstrapPlan> run(BootstrapRequest request) =>
        bootstrap(root: root, request: request, url: upstream.path);

    String read(String file) => File(p.join(root, file)).readAsStringSync();

    bool exists(String file) =>
        FileSystemEntity.typeSync(p.join(root, file)) !=
        FileSystemEntityType.notFound;

    /// The text an import of [_highlightsPath] at [commit] writes.
    String imported(String commit, String text) =>
        '; Derived from nvim-treesitter $nvimTreesitterUrl, '
        '$_highlightsPath @ $commit, Apache-2.0.\n'
        '; Unchanged.\n\n$text';

    Map<String, Object?> importedEntry(String commit) => {
      'origin': 'nvim',
      'changed': false,
      'upstream': {
        'repo': nvimTreesitterUrl,
        'commit': commit,
        'path': _highlightsPath,
      },
    };

    /// Sets the user-immutable flag on [file], so renaming onto it or
    /// removing it fails; the flag is cleared when the test ends.
    void immutable(String file) {
      final path = p.join(root, file);
      check(Process.runSync('chflags', ['uchg', path]).exitCode).equals(0);
      addTearDown(() => Process.runSync('chflags', ['nouchg', path]));
    }

    void mutable(String file) => check(
      Process.runSync('chflags', ['nouchg', p.join(root, file)]).exitCode,
    ).equals(0);

    /// Deletes folds.scm from nvim-treesitter's HEAD.
    Future<void> dropUpstreamFolds() async {
      await upstream.git(['rm', '--quiet', 'runtime/queries/mylang/folds.scm']);
      await upstream.git(['commit', '--quiet', '-m', 'drop folds']);
    }

    /// The staging directories a write left under `.cache/`.
    List<String> staging() => [
      if (Directory(p.join(root, '.cache')).existsSync())
        for (final entity in Directory(p.join(root, '.cache')).listSync())
          if (p.basename(entity.path).startsWith('bootstrap-'))
            p.basename(entity.path),
    ];

    /// Gives queries/mylang/highlights.scm [text] and [entry].
    void existingHighlights(String text, Map<String, Object?> entry) {
      _write(root, 'queries/mylang/highlights.scm', text);
      _write(
        root,
        'tool/query_provenance.json',
        withProvenanceEntries(provenance, {
          'queries/mylang/highlights.scm': entry,
        }),
      );
    }

    test('a dry run plans every file and entry, writing none', () async {
      final plan = await run(request(dryRun: true));

      check(plan.commit).equals(newCommit);
      check(plan.files.keys.toList()).deepEquals([
        'queries/mylang/highlights.scm',
        'queries/mylang/folds.scm',
        'queries/mylang/tags.scm',
        'queries/mylang/config.json',
      ]);
      check(plan.entries.keys.toList()).deepEquals([
        'queries/mylang/highlights.scm',
        'queries/mylang/folds.scm',
        'queries/mylang/tags.scm',
      ]);
      check(
        plan.entries['queries/mylang/tags.scm'],
      ).isNotNull().deepEquals(writtenHereProvenance);
      check(exists('queries/mylang')).isFalse();
      check(read('tool/query_provenance.json')).equals(provenance);
    });

    test('writes a plan the provenance and header checks accept', () async {
      await run(request());

      final reading = readRepositoryProvenance(root);
      check(reading.problems).isEmpty();
      check(reading.entries.keys.toSet()).deepEquals({
        'queries/other/highlights.scm',
        'queries/mylang/highlights.scm',
        'queries/mylang/folds.scm',
        'queries/mylang/tags.scm',
      });
      check(
        queryHeaderCheck(
          root,
          reading.entries,
          (repository) => fail('$repository is a grammar repository'),
        ),
      ).isEmpty();
      check(read('queries/mylang/tags.scm')).equals(tagsPlaceholder);
      check(
        read('queries/mylang/config.json'),
      ).equals(configSkeleton('mylang'));
      check(staging()).isEmpty();
    });

    test('shows the plan before writing it', () async {
      var shown = false;
      await bootstrap(
        root: root,
        request: request(),
        url: upstream.path,
        beforeWriting: (plan) {
          shown = true;
          check(exists('queries/mylang')).isFalse();
        },
      );

      check(shown).isTrue();
      check(exists('queries/mylang/highlights.scm')).isTrue();
    });

    test('writes the provenance only after every file', () async {
      final plan = await run(request(dryRun: true));
      for (final MapEntry(key: file, value: content) in plan.files.entries) {
        _write(root, file, content);
      }
      immutable('queries/mylang/folds.scm');

      await check(run(request(force: true))).throws<FileSystemException>();

      check(read('tool/query_provenance.json')).equals(provenance);
      check(staging()).isEmpty();
    });

    test('removes an import only after writing the provenance', () async {
      await run(request());
      await dropUpstreamFolds();
      immutable('queries/mylang/folds.scm');

      await check(run(request(force: true))).throws<FileSystemException>();

      check(
        read('tool/query_provenance.json'),
      ).not((it) => it.contains('queries/mylang/folds.scm'));
      check(exists('queries/mylang/folds.scm')).isTrue();
      mutable('queries/mylang/folds.scm');
      final rerun = await run(request(force: true));
      check(rerun.removals).deepEquals(['queries/mylang/folds.scm']);
      check(exists('queries/mylang/folds.scm')).isFalse();
      check(readRepositoryProvenance(root).problems).isEmpty();
    });

    test(
      'refuses a planned path that is not a file, writing nothing',
      () async {
        Directory(
          p.join(root, 'queries', 'mylang', 'folds.scm'),
        ).createSync(recursive: true);

        await check(run(request(force: true))).throws<BootstrapException>(
          (it) => it
              .has((e) => e.message, 'message')
              .equals('queries/mylang/folds.scm is not a file'),
        );
        check(exists('.cache')).isFalse();
        check(read('tool/query_provenance.json')).equals(provenance);
      },
    );

    test('refuses a change made while nvim-treesitter was fetched', () async {
      final store = nvimStoreDirectory(root);
      await fetchNvimCommit(store, url: upstream.path);
      const edited = '{"edited": "while fetching"}';
      final target = p.join(root, 'tool', 'query_provenance.json');
      final hook = File(p.join(store, '.git', 'hooks', 'reference-transaction'))
        ..createSync(recursive: true)
        ..writeAsStringSync("#!/bin/sh\nprintf '%s' '$edited' > '$target'\n");
      check(Process.runSync('chmod', ['+x', hook.path]).exitCode).equals(0);
      await upstream.commit({_highlightsPath: bytes('(moved) @x\n')});

      await check(run(request())).throws<BootstrapException>(
        (it) => it
            .has((e) => e.message, 'message')
            .equals(
              'changed since the bootstrap was planned; run it again\n'
              '  tool/query_provenance.json',
            ),
      );
      check(read('tool/query_provenance.json')).equals(edited);
      check(exists('queries/mylang')).isFalse();
    });

    test('refuses to write over a change made since planning', () async {
      final plan = await run(request(dryRun: true));
      final edited = withProvenanceEntries(provenance, {
        'queries/other/folds.scm': _here,
      });
      _write(root, 'tool/query_provenance.json', edited);

      check(() => writeBootstrap(root, plan))
          .throws<BootstrapException>()
          .has((e) => e.message, 'message')
          .equals(
            'changed since the bootstrap was planned; run it again\n'
            '  tool/query_provenance.json',
          );
      check(exists('queries/mylang')).isFalse();
      check(read('tool/query_provenance.json')).equals(edited);
    });

    test(
      'refuses an existing language without force, fetching nothing',
      () async {
        _write(root, 'queries/mylang/highlights.scm', _otherQuery);

        await check(run(request())).throws<BootstrapException>(
          (it) => it
              .has((e) => e.message, 'message')
              .startsWith('queries/mylang/ exists'),
        );
        check(exists('.cache')).isFalse();
      },
    );

    test(
      'with force replaces an unchanged import and keeps the rest',
      () async {
        const tags = '(function) @definition.function\n';
        const config = '{"symbol": "mylang"}\n';
        existingHighlights(
          imported(oldCommit, _oldHighlights),
          importedEntry(oldCommit),
        );
        _write(root, 'queries/mylang/tags.scm', tags);
        _write(root, 'queries/mylang/config.json', config);
        _write(
          root,
          'tool/query_provenance.json',
          withProvenanceEntries(read('tool/query_provenance.json'), {
            'queries/mylang/tags.scm': _here,
          }),
        );

        final plan = await run(request(force: true));

        check(plan.files.keys.toList()).deepEquals([
          'queries/mylang/highlights.scm',
          'queries/mylang/folds.scm',
        ]);
        check(
          read('queries/mylang/highlights.scm'),
        ).equals(imported(newCommit, _newHighlights));
        check(read('queries/mylang/tags.scm')).equals(tags);
        check(read('queries/mylang/config.json')).equals(config);
        check(readRepositoryProvenance(root).problems).isEmpty();
      },
    );

    /// Checks that a forced run refuses queries/mylang/highlights.scm and
    /// writes nothing.
    Future<void> refusesHeldWork() async {
      final before = read('tool/query_provenance.json');
      final highlights = read('queries/mylang/highlights.scm');

      await check(run(request(force: true))).throws<BootstrapException>(
        (it) => it
            .has((e) => e.message, 'message')
            .contains(
              'these files hold other work\n'
              '  queries/mylang/highlights.scm',
            ),
      );
      check(read('queries/mylang/highlights.scm')).equals(highlights);
      check(read('tool/query_provenance.json')).equals(before);
      check(exists('queries/mylang/folds.scm')).isFalse();
    }

    test('with force refuses a file written here', () async {
      existingHighlights(_otherQuery, _here);

      await refusesHeldWork();
    });

    test('with force refuses a file marked changed', () async {
      existingHighlights(imported(oldCommit, _oldHighlights), {
        ...importedEntry(oldCommit),
        'changed': true,
      });

      await refusesHeldWork();
    });

    test('with force refuses an edited file marked unchanged', () async {
      existingHighlights(
        '${imported(oldCommit, _oldHighlights)}(edit) @x\n',
        importedEntry(oldCommit),
      );

      await refusesHeldWork();
    });

    test('with force completes a run stopped before its entries', () async {
      final plan = await run(request(dryRun: true));
      for (final MapEntry(key: file, value: content) in plan.files.entries) {
        _write(root, file, content);
      }
      check(readRepositoryProvenance(root).problems).isNotEmpty();

      await check(run(request())).throws<BootstrapException>();
      await run(request(force: true));

      check(readRepositoryProvenance(root).problems).isEmpty();
      check(read('tool/query_provenance.json')).equals(plan.provenanceJson);
    });

    test(
      'with force completes a stopped re-import under older entries',
      () async {
        await run(request(commit: oldCommit));
        final plan = await run(request(force: true, dryRun: true));
        for (final MapEntry(:key, :value) in plan.files.entries) {
          _write(root, key, value);
        }
        check(read('tool/query_provenance.json')).contains(oldCommit);
        final movedCommit = await upstream.commit({
          _highlightsPath: bytes('(moved) @variable\n'),
        });

        final rerun = await run(request(force: true));

        check(rerun.commit).equals(movedCommit);
        check(readRepositoryProvenance(root).problems).isEmpty();
        check(
          read('tool/query_provenance.json'),
        ).not((it) => it.contains(oldCommit));
      },
    );

    test('with force completes a stopped run after HEAD has moved', () async {
      final plan = await run(request(dryRun: true));
      for (final MapEntry(key: file, value: content) in plan.files.entries) {
        _write(root, file, content);
      }
      const moved = '(moved) @variable\n';
      final movedCommit = await upstream.commit({
        _highlightsPath: bytes(moved),
      });

      final rerun = await run(request(force: true));

      check(rerun.commit).equals(movedCommit);
      check(
        read('queries/mylang/highlights.scm'),
      ).equals(imported(movedCommit, moved));
      check(readRepositoryProvenance(root).problems).isEmpty();
    });

    test('with force removes an import the commit no longer has', () async {
      await run(request());
      _write(root, 'queries/mylang/indents.scm', _otherQuery);
      _write(
        root,
        'tool/query_provenance.json',
        withProvenanceEntries(read('tool/query_provenance.json'), {
          'queries/mylang/indents.scm': _here,
        }),
      );
      await dropUpstreamFolds();

      final plan = await run(request(force: true));

      check(plan.removals).deepEquals(['queries/mylang/folds.scm']);
      check(exists('queries/mylang/folds.scm')).isFalse();
      check(read('queries/mylang/indents.scm')).equals(_otherQuery);
      final reading = readRepositoryProvenance(root);
      check(reading.problems).isEmpty();
      check(
        reading.entries.keys,
      ).not((it) => it.contains('queries/mylang/folds.scm'));
    });

    test('reports a git failure while checking an import', () async {
      final blob = await upstream.git([
        'rev-parse',
        '$newCommit:$_highlightsPath',
      ]);
      existingHighlights(imported(blob, _oldHighlights), importedEntry(blob));

      await check(run(request(force: true))).throws<GitException>(
        (it) => it.has((e) => e.exitCode, 'exitCode').equals(128),
      );
    });

    test(
      'with force refuses an import naming a commit the store lacks',
      () async {
        final missing = 'a' * 40;
        existingHighlights(
          imported(missing, _oldHighlights),
          importedEntry(missing),
        );

        await refusesHeldWork();
      },
    );

    test(
      'with force refuses an import naming a path its commit lacks',
      () async {
        existingHighlights(imported(newCommit, _oldHighlights), {
          ...importedEntry(newCommit),
          'upstream': {
            'repo': nvimTreesitterUrl,
            'commit': newCommit,
            'path': 'queries/mylang/highlights.scm',
          },
        });

        await refusesHeldWork();
      },
    );

    test('with force refuses an import of a file that is not UTF-8', () async {
      await upstream.git(['checkout', '--quiet', '-b', 'latin', newCommit]);
      final latin = await upstream.commit({
        _highlightsPath: [0x28, 0x62, 0xe9, 0x29, 0x0a],
      });
      await upstream.git(['checkout', '--quiet', 'main']);
      existingHighlights(_otherQuery, importedEntry(latin));

      await refusesHeldWork();
    });

    /// Gives queries/mylang/injections.scm an unchanged copy of c-sharp's
    /// highlights, recorded as such, and returns its text.
    String copyOfAnotherLanguage() {
      const source = 'runtime/queries/c_sharp/highlights.scm';
      final copy =
          '; Derived from nvim-treesitter $nvimTreesitterUrl, '
          '$source @ $newCommit, Apache-2.0.\n; Unchanged.\n\n'
          '(name) @type\n';
      _write(root, 'queries/mylang/injections.scm', copy);
      _write(
        root,
        'tool/query_provenance.json',
        withProvenanceEntries(read('tool/query_provenance.json'), {
          'queries/mylang/injections.scm': {
            'origin': 'nvim',
            'changed': false,
            'upstream': {
              'repo': nvimTreesitterUrl,
              'commit': newCommit,
              'path': source,
            },
          },
        }),
      );
      return copy;
    }

    test('with force keeps an import of another language', () async {
      await run(request());
      final copy = copyOfAnotherLanguage();

      final plan = await run(request(force: true));

      check(plan.removals).isEmpty();
      check(read('queries/mylang/injections.scm')).equals(copy);
      check(readRepositoryProvenance(root).problems).isEmpty();
    });

    test(
      'with force refuses to replace an import of another language',
      () async {
        await run(request());
        final copy = copyOfAnotherLanguage();
        await upstream.commit({
          'runtime/queries/mylang/injections.scm': bytes('(x) @injection\n'),
        });

        await check(run(request(force: true))).throws<BootstrapException>(
          (it) => it
              .has((e) => e.message, 'message')
              .contains(
                'these files hold other work\n'
                '  queries/mylang/injections.scm',
              ),
        );
        check(read('queries/mylang/injections.scm')).equals(copy);
      },
    );

    /// Gives [directory] under queries/ a highlights.scm written here.
    void existingLanguage(String directory) {
      _write(root, 'queries/$directory/highlights.scm', _otherQuery);
      _write(
        root,
        'tool/query_provenance.json',
        withProvenanceEntries(read('tool/query_provenance.json'), {
          'queries/$directory/highlights.scm': _here,
        }),
      );
    }

    for (final (existing, requested) in [
      ('c-sharp', 'c_sharp'),
      ('c_sharp', 'c-sharp'),
    ]) {
      test(
        'refuses $requested while queries/$existing/ holds the same language',
        () async {
          existingLanguage(existing);
          final before = read('tool/query_provenance.json');

          for (final force in [false, true]) {
            await check(
              run(request(language: requested, force: force)),
            ).throws<BootstrapException>(
              (it) => it
                  .has((e) => e.message, 'message')
                  .equals(
                    'queries/$existing/ holds the language nvim-treesitter '
                    'names c_sharp; bootstrap it with --language=$existing',
                  ),
            );
          }
          check(exists('queries/$requested')).isFalse();
          check(exists('.cache')).isFalse();
          check(read('tool/query_provenance.json')).equals(before);
        },
      );
    }

    test('refuses a file where the language directory belongs', () async {
      _write(root, 'queries/mylang', _otherQuery);

      for (final force in [false, true]) {
        await check(run(request(force: force))).throws<BootstrapException>(
          (it) => it
              .has((e) => e.message, 'message')
              .equals('queries/mylang is not a directory'),
        );
      }
      check(exists('.cache')).isFalse();
    });

    test('clears a staging directory a killed run left', () async {
      // A leftover where the first staged file is written.
      Directory(
        p.join(root, '.cache', 'bootstrap-staging', '0'),
      ).createSync(recursive: true);

      await run(request());

      check(staging()).isEmpty();
    });

    test('with force allows a missing entry only for its own files', () async {
      _write(root, 'queries/mylang/textobjects.scm', _otherQuery);

      await check(run(request(force: true))).throws<BootstrapException>(
        (it) => it
            .has((e) => e.message, 'message')
            .contains('queries/mylang/textobjects.scm: no entry'),
      );
      check(exists('.cache')).isFalse();
    });

    test('with force refuses a problem other than a missing entry', () async {
      await run(request());
      _write(root, 'queries/mylang/textobjects.scm', _otherQuery);
      final entry = '"queries/mylang/textobjects.scm": ${jsonEncode(_here)}';
      final duplicated = read(
        'tool/query_provenance.json',
      ).replaceFirst('{\n', '{\n  $entry,\n  $entry,\n');
      _write(root, 'tool/query_provenance.json', duplicated);

      await check(run(request(force: true))).throws<BootstrapException>(
        (it) => it
            .has((e) => e.message, 'message')
            .contains('queries/mylang/textobjects.scm: 2 entries'),
      );
      check(read('tool/query_provenance.json')).equals(duplicated);
    });

    test('refuses a provenance file with problems, fetching nothing', () async {
      _write(root, 'queries/other/folds.scm', _otherQuery);

      for (final force in [false, true]) {
        await check(run(request(force: force))).throws<BootstrapException>(
          (it) => it
              .has((e) => e.message, 'message')
              .contains('queries/other/folds.scm: no entry'),
        );
      }
      check(exists('.cache')).isFalse();
    });

    test('refuses a commit no branch of origin contains', () async {
      await check(
        run(request(commit: pullCommit)),
      ).throws<BootstrapException>();
      check(exists('queries/mylang')).isFalse();
      check(read('tool/query_provenance.json')).equals(provenance);
    });

    test('refuses files the header check would reject', () async {
      await check(run(request(language: 'stray'))).throws<BootstrapException>(
        (it) => it
            .has((e) => e.message, 'message')
            .contains(
              'queries/stray/highlights.scm: names nvim-treesitter below '
              'its header',
            ),
      );
      check(exists('queries/stray')).isFalse();
      check(read('tool/query_provenance.json')).equals(provenance);
    });
  });

  group('parseBootstrapArguments', () {
    const commit = '0123456789abcdef0123456789abcdef01234567';

    test('reads every option', () {
      check(
        parseBootstrapArguments([
          '--language=c-sharp',
          '--commit=$commit',
          '--force',
          '--dry-run',
        ]),
      ).equals((
        language: 'c-sharp',
        commit: commit,
        force: true,
        dryRun: true,
      ));
      check(
        parseBootstrapArguments(['--language=nix']),
      ).equals((language: 'nix', commit: null, force: false, dryRun: false));
    });

    for (final args in [
      <String>[],
      ['--force'],
      ['--language=Nix'],
      ['--language=../nix'],
      ['--language=nix', '--commit=0123456'],
      ['--language=nix', '--commit=${commit.toUpperCase()}'],
      ['--language=nix', '--force', '--force'],
      ['--language=nix', '--language=lua'],
      ['--language=nix', '--publish'],
    ]) {
      test('refuses ${args.join(' ')}', () {
        check(parseBootstrapArguments(args)).isNull();
      });
    }
  });

  group('the command', () {
    Future<ProcessResult> command(List<String> args) =>
        Process.run('dart', ['run', 'tool/bootstrap_language.dart', ...args]);

    test('exits 64 with its usage for arguments it does not take', () async {
      final result = await command(['--language=Nix']);

      check(result.exitCode).equals(64);
      check('${result.stderr}').startsWith('usage: ');
    });

    for (final args in [
      ['--help'],
      ['--language=nix', '--help'],
      ['-h', '--force'],
    ]) {
      test('prints its usage for ${args.join(' ')}', () async {
        final result = await command(args);

        check(result.exitCode).equals(0);
        check('${result.stdout}').startsWith('usage: ');
      });
    }

    test('exits 1 with a refusal, printing nothing else', () async {
      final result = await command(['--language=c', '--dry-run']);

      check(result.exitCode).equals(1);
      check('${result.stderr}').contains('✗ queries/c/ exists');
      check('${result.stdout}').isEmpty();
    });
  });

  group('withProvenanceEntries', () {
    test('adds and replaces entries and sorts every file', () {
      final json = withProvenanceEntries(
        jsonEncode({
          'queries/z/folds.scm': _here,
          'queries/a/folds.scm': {'origin': 'nvim'},
        }),
        {'queries/a/folds.scm': _here, 'queries/m/tags.scm': _here},
      );

      check(json).endsWith('}\n');
      check(
        (jsonDecode(json) as Map<String, Object?>).keys.toList(),
      ).deepEquals([
        'queries/a/folds.scm',
        'queries/m/tags.scm',
        'queries/z/folds.scm',
      ]);
      check(
        (jsonDecode(json) as Map<String, Object?>)['queries/a/folds.scm'],
      ).isA<Map<String, Object?>>().deepEquals(_here);
    });

    test('rewrites the committed provenance file byte for byte', () {
      final committed = File(
        p.join('tool', 'query_provenance.json'),
      ).readAsStringSync();

      check(withProvenanceEntries(committed, {})).equals(committed);
    });
  });
}

/// Writes [content] to [file] under [root], creating its directory.
void _write(String root, String file, String content) {
  final target = File(p.join(root, file));
  target.parent.createSync(recursive: true);
  target.writeAsStringSync(content);
}
