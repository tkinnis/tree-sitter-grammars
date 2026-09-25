import 'dart:io';

import 'package:checks/checks.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../tool/src/git.dart';
import '../tool/src/grammar_sources.dart';
import 'support/git_fixture.dart';

const _parser = 'int parse(void) {\n  return 0;\n}\n';
const _header = '#define ABI 15\n';

void main() {
  late Directory temporary;
  late FixtureRepository upstream;
  late String commit;

  setUp(() async {
    temporary = Directory.systemTemp.createTempSync('sources_test');
    upstream = await FixtureRepository.create(
      p.join(temporary.path, 'tree-sitter-x'),
    );
    commit = await upstream.commit({
      'src/parser.c': bytes(_parser),
      'src/tree_sitter/parser.h': bytes(_header),
      'src/crlf.txt': bytes('kept\r\nas committed\r\n'),
      'bin/run': bytes('#!/bin/sh\n'),
    });
  });

  tearDown(() => temporary.deleteSync(recursive: true));

  String path(String relative) => p.join(temporary.path, relative);

  group('ensureObjectStore', () {
    test('creates a store whose origin is the url', () async {
      await ensureObjectStore(runGit, path('store'), upstream.path);

      check(
        await fixtureGit(path('store'), ['remote', 'get-url', 'origin']),
      ).equals(upstream.path);
    });

    test('accepts another spelling of the same url', () async {
      await ensureObjectStore(runGit, path('store'), upstream.path);

      await ensureObjectStore(runGit, path('store'), '${upstream.path}.git/');
    });

    test('refuses a store whose origin is another repository', () async {
      final store = await FixtureRepository.create(path('store'));
      await store.git(['remote', 'add', 'origin', path('elsewhere')]);

      await check(
        ensureObjectStore(runGit, store.path, upstream.path),
      ).throws<GrammarSourceException>(
        (it) => it
            .has((e) => e.message, 'message')
            .contains('origin of ${store.path} is ${path('elsewhere')}'),
      );
    });

    test('refuses a directory that is not itself a repository', () async {
      Directory(path('tree-sitter-x/plain')).createSync();

      await check(
        ensureObjectStore(runGit, path('tree-sitter-x/plain'), upstream.path),
      ).throws<GrammarSourceException>(
        (it) => it
            .has((e) => e.message, 'message')
            .endsWith('is not a git repository'),
      );
    });
  });

  group('ensureCommit', () {
    test('fetches a commit the store lacks from origin', () async {
      await ensureObjectStore(runGit, path('store'), upstream.path);

      await ensureCommit(runGit, path('store'), commit, 'tree-sitter-x');

      check(
        await fixtureGit(path('store'), ['cat-file', '-t', commit]),
      ).equals('commit');
    });

    test('fails when origin does not have the commit', () async {
      await ensureObjectStore(runGit, path('store'), upstream.path);
      const missing = '0123456789abcdef0123456789abcdef01234567';

      await check(
        ensureCommit(runGit, path('store'), missing, 'x'),
      ).throws<GitException>();
    });

    test('fails when a fetch that succeeds still lacks the commit', () async {
      const missing = '0123456789abcdef0123456789abcdef01234567';
      Future<String> git(String directory, List<String> arguments) async =>
          switch (arguments) {
            ['cat-file', ...] => throw GitException(
              directory,
              arguments,
              1,
              '',
            ),
            ['fetch', ...] => '',
            _ => throw StateError('unexpected git ${arguments.join(' ')}'),
          };

      await check(
        ensureCommit(git, 'store', missing, 'tree-sitter-x'),
      ).throws<GrammarSourceException>(
        (it) => it
            .has((e) => e.message, 'message')
            .equals('tree-sitter-x: origin did not supply $missing'),
      );
    });
  });

  group('extractCommit', () {
    test('writes every committed file with its committed bytes', () async {
      await extractCommit(upstream.path, commit, path('out'));

      check(File(path('out/src/parser.c')).readAsStringSync()).equals(_parser);
      check(
        File(path('out/src/crlf.txt')).readAsStringSync(),
      ).equals('kept\r\nas committed\r\n');
      check(File(path('out/src/tree_sitter/parser.h')).existsSync()).isTrue();
    });

    test('ignores global attributes and configuration of the user', () async {
      const hostile = '* text eol=crlf\n*.h export-ignore\n';
      File(path('attributes')).writeAsStringSync(hostile);
      Directory(path('xdg/git')).createSync(recursive: true);
      File(path('xdg/git/attributes')).writeAsStringSync(hostile);
      final config =
          '[core]\n\tattributesFile = ${path('attributes')}\n'
          '\tautocrlf = true\n';
      File(path('gitconfig')).writeAsStringSync(config);
      Directory(path('home')).createSync();
      File(path('home/.gitconfig')).writeAsStringSync(config);
      final environment = {
        ...Platform.environment,
        'HOME': path('home'),
        'XDG_CONFIG_HOME': path('xdg'),
        'GIT_CONFIG_GLOBAL': path('gitconfig'),
        'GIT_CONFIG_PARAMETERS':
            "'core.attributesfile'='${path('attributes')}'",
        'GIT_CONFIG_COUNT': '1',
        'GIT_CONFIG_KEY_0': 'core.attributesFile',
        'GIT_CONFIG_VALUE_0': path('attributes'),
      };

      await extractCommit(
        upstream.path,
        commit,
        path('out'),
        environment: environment,
      );

      check(File(path('out/src/parser.c')).readAsStringSync()).equals(_parser);
      check(File(path('out/src/tree_sitter/parser.h')).existsSync()).isTrue();
    });

    test('reads the pinned commit, never a replacement for it', () async {
      final other = await upstream.commit({'src/parser.c': bytes('other\n')});
      await upstream.git(['replace', commit, other]);

      await extractCommit(upstream.path, commit, path('out'));

      check(File(path('out/src/parser.c')).readAsStringSync()).equals(_parser);
    });

    test('refuses bytes the repository\'s own attributes convert', () async {
      Directory(path('tree-sitter-x/.git/info')).createSync(recursive: true);
      File(
        path('tree-sitter-x/.git/info/attributes'),
      ).writeAsStringSync('*.c text eol=crlf\n');

      await check(
        extractCommit(upstream.path, commit, path('out')),
      ).throws<GrammarSourceException>(
        (it) => it
            .has((e) => e.message, 'message')
            .contains(
              'src/parser.c: extracted bytes are not the committed blob',
            ),
      );
    });

    test('refuses files the commit\'s own attributes leave out', () async {
      final ignoring = await upstream.commit({
        '.gitattributes': bytes('src/tree_sitter/** export-ignore\n'),
      });

      await check(
        extractCommit(upstream.path, ignoring, path('out')),
      ).throws<GrammarSourceException>(
        (it) => it
            .has((e) => e.message, 'message')
            .contains('src/tree_sitter/parser.h: committed but not extracted'),
      );
    });

    test('checks a committed symbolic link by its target', () async {
      Link(path('tree-sitter-x/src/alias.c')).createSync('parser.c');
      final linked = await upstream.commit({});

      await extractCommit(upstream.path, linked, path('out'));

      check(Link(path('out/src/alias.c')).targetSync()).equals('parser.c');
    });

    test('refuses a destination that already exists', () async {
      Directory(path('out')).createSync();

      await check(
        extractCommit(upstream.path, commit, path('out')),
      ).throws<GrammarSourceException>();
    });
  });
}
