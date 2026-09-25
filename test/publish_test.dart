import 'dart:convert';
import 'dart:io';

import 'package:checks/checks.dart';
import 'package:test/test.dart';

import '../tool/src/publish.dart';

const _archive = '/out/grammars-macos-arm64.tar.gz';
const _bundle = '/out/sources/tree-sitter-0000.tar.gz';
const _assets = {_archive: 'aa', _bundle: 'bb'};

/// Answers `gh` from [answers] by its first two arguments, recording every
/// call in [calls].
ProcessRunner _gh(
  Map<String, ProcessResult> answers,
  List<List<String>> calls,
) => (executable, arguments) async {
  check(executable).equals('gh');
  calls.add(arguments);
  return answers[arguments.take(2).join(' ')] ??
      (throw StateError('unexpected gh ${arguments.join(' ')}'));
};

ProcessResult _result(int exitCode, {String stdout = '', String stderr = ''}) =>
    ProcessResult(0, exitCode, stdout, stderr);

final _notFound = _result(1, stderr: 'release not found\n');

String _digests(Map<String, String> digests) => jsonEncode([
  for (final MapEntry(:key, :value) in digests.entries)
    {'name': key, 'digest': 'sha256:$value'},
]);

void main() {
  test('creates the release from the pushed tag with every asset', () async {
    final calls = <List<String>>[];

    await publishRelease(
      tag: 'v1.1.0',
      assets: _assets,
      notesFile: '/out/release-notes.md',
      run: _gh({
        'release view': _notFound,
        'release create': _result(0),
        'api repos/$releaseRepository/releases/tags/v1.1.0': _result(
          0,
          stdout: _digests({
            'grammars-macos-arm64.tar.gz': 'aa',
            'tree-sitter-0000.tar.gz': 'bb',
          }),
        ),
      }, calls),
    );

    check(calls[1]).deepEquals([
      'release',
      'create',
      'v1.1.0',
      '--repo',
      releaseRepository,
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

  test('refuses a release that exists, creating nothing', () async {
    final calls = <List<String>>[];

    await check(
      publishRelease(
        tag: 'v1.1.0',
        assets: _assets,
        notesFile: '/out/release-notes.md',
        run: _gh({'release view': _result(0, stdout: '{}')}, calls),
      ),
    ).throws<PublishException>(
      (it) => it.has((e) => e.message, 'message').contains('exists'),
    );
    check(calls).length.equals(1);
  });

  test('stops when gh cannot tell whether the release exists', () async {
    await check(
      publishRelease(
        tag: 'v1.1.0',
        assets: _assets,
        notesFile: '/out/release-notes.md',
        run: _gh({
          'release view': _result(1, stderr: 'HTTP 401: Bad credentials'),
        }, []),
      ),
    ).throws<PublishException>(
      (it) => it.has((e) => e.message, 'message').contains('401'),
    );
  });

  test('refuses an upload GitHub reports with another digest', () async {
    await check(
      publishRelease(
        tag: 'v1.1.0',
        assets: _assets,
        notesFile: '/out/release-notes.md',
        run: _gh({
          'release view': _notFound,
          'release create': _result(0),
          'api repos/$releaseRepository/releases/tags/v1.1.0': _result(
            0,
            stdout: _digests({
              'grammars-macos-arm64.tar.gz': 'aa',
              'tree-sitter-0000.tar.gz': 'cc',
            }),
          ),
        }, []),
      ),
    ).throws<PublishException>(
      (it) => it
          .has((e) => e.message, 'message')
          .contains('tree-sitter-0000.tar.gz: GitHub reports sha256:cc'),
    );
  });

  test('the notes name the runtime, the archive and every bundle', () {
    final notes = releaseNotes({
      'deploymentTarget': '13.0',
      'treeSitter': {'tag': 'v0.27.0', 'commit': 'c0ffee'},
      'sources': {
        'tree-sitter': {
          'commit': 'c0ffee',
          'file': 'sources/tree-sitter-c0ffee.tar.gz',
          'sha256': 'bb',
        },
      },
    }, 'aa');

    check(notes)
      ..contains('tree-sitter v0.27.0 (c0ffee)')
      ..contains('sha256 `aa`')
      ..contains(
        '| tree-sitter | `c0ffee` | `tree-sitter-c0ffee.tar.gz` | `bb` |',
      );
  });
}
