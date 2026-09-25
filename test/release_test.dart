import 'dart:io';

import 'package:checks/checks.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../tool/src/git.dart';
import '../tool/src/release.dart';
import 'support/git_fixture.dart';

const _runtime = '6070dbfefd326bd735e5683eb128cc1b57dad0c0';

void main() {
  late Directory temporary;
  late FixtureRepository repository;
  late String head;

  setUp(() async {
    temporary = Directory.systemTemp.createTempSync('release_test');
    repository = await FixtureRepository.create(
      p.join(temporary.path, 'grammars'),
    );
    await repository.commit({'README.md': bytes('grammars\n')});
    // An uninitialised submodule: an empty directory at the gitlink.
    Directory(p.join(repository.path, 'tree-sitter')).createSync();
    await repository.git([
      'update-index',
      '--add',
      '--cacheinfo',
      '160000,$_runtime,tree-sitter',
    ]);
    head = await repository.commit({});
  });

  tearDown(() => temporary.deleteSync(recursive: true));

  Future<String> preflight({bool dryRun = false}) =>
      checkReleasePreflight(runGit, repository.path, 'v1.1.0', dryRun: dryRun);

  Future<void> refuses(Future<void> Function() run, String message) =>
      check(run()).throws<ReleaseException>(
        (it) => it.has((e) => e.message, 'message').contains(message),
      );

  test('accepts an annotated tag at HEAD, and returns HEAD', () async {
    await repository.git(['tag', '-a', 'v1.1.0', '-m', 'v1.1.0']);

    check(await preflight()).equals(head);
  });

  test('refuses a branch named like the tag', () async {
    await repository.git(['branch', 'v1.1.0']);

    await refuses(preflight, 'no tag v1.1.0');
  });

  test('refuses a lightweight tag', () async {
    await repository.git(['tag', 'v1.1.0']);

    await refuses(preflight, 'v1.1.0 is a lightweight tag');
  });

  test('refuses an annotated tag on another commit', () async {
    await repository.git(['tag', '-a', 'v1.1.0', '-m', 'v1.1.0', 'HEAD~1']);

    await refuses(preflight, 'HEAD is $head, but v1.1.0 is');
  });

  test('refuses a dirty working tree, even in a dry run', () async {
    File(p.join(repository.path, 'README.md')).writeAsStringSync('edited\n');

    await refuses(() => preflight(dryRun: true), 'clean working tree');
  });

  test('a dry run needs no tag, and returns HEAD', () async {
    await repository.git(['branch', 'v1.1.0']);

    check(await preflight(dryRun: true)).equals(head);
  });

  group('checkRecordedRuntime', () {
    test('accepts the commit recording the pinned runtime', () async {
      await checkRecordedRuntime(runGit, repository.path, head, _runtime);
    });

    test('refuses a commit recording another runtime', () async {
      await repository.git([
        'update-index',
        '--cacheinfo',
        '160000,${'1' * 40},tree-sitter',
      ]);
      final moved = await repository.commit({});

      await refuses(
        () => checkRecordedRuntime(runGit, repository.path, moved, _runtime),
        'records the tree-sitter submodule at ${'1' * 40}',
      );
    });

    test('reads the given commit, not HEAD', () async {
      await repository.git([
        'update-index',
        '--cacheinfo',
        '160000,${'1' * 40},tree-sitter',
      ]);
      await repository.commit({});

      await checkRecordedRuntime(runGit, repository.path, head, _runtime);
    });
  });

  group('checkUnchangedSince', () {
    Future<void> unchanged() =>
        checkUnchangedSince(runGit, repository.path, head);

    test('accepts the same commit with a clean working tree', () async {
      await unchanged();
    });

    test('refuses an edit to a committed file', () async {
      File(p.join(repository.path, 'README.md')).writeAsStringSync('edited\n');

      await refuses(unchanged, 'the working tree changed during the build');
    });

    test('refuses a file added to the working tree', () async {
      File(p.join(repository.path, 'stray.txt')).writeAsStringSync('stray\n');

      await refuses(unchanged, 'stray.txt');
    });

    test('refuses a commit made during the build', () async {
      final next = await repository.commit({'README.md': bytes('next\n')});

      await refuses(unchanged, 'HEAD moved from $head to $next');
    });
  });
}
