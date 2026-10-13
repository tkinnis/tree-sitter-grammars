import 'dart:io';

import 'package:checks/checks.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

final _pinned = RegExp(r'^[\w.-]+/[\w./-]+@[0-9a-f]{40}$');

/// The owners of the actions the repository's settings allow: it permits
/// GitHub-owned actions only (`allowed_actions: selected`,
/// `github_owned_allowed: true`, `verified_allowed: false`, no patterns), so
/// an action of any other owner fails the run at startup.
const _allowedOwners = {'actions', 'github'};

final _hex64 = RegExp(r'^[0-9a-f]{64}$');

/// Every way the workflow in [source] departs from what a workflow that
/// attaches to a release may be.
List<String> workflowProblems(String source) {
  final workflow = loadYaml(source) as YamlMap;
  final jobs = workflow['jobs'] as YamlMap;
  final problems = <String>[];

  if (workflow['permissions'] is! YamlMap ||
      (workflow['permissions'] as YamlMap).isNotEmpty) {
    problems.add('top-level permissions are not empty');
  }
  const writers = {'build', 'attach'};
  for (final MapEntry(key: name, value: job) in jobs.entries) {
    final permissions = (job as YamlMap)['permissions'];
    final contents = permissions is YamlMap ? permissions['contents'] : null;
    if (permissions is! YamlMap) {
      problems.add('job $name has no permissions of its own');
    }
    if ((contents == 'write') != writers.contains(name)) {
      problems.add(
        'job $name ${contents == 'write' ? 'holds' : 'lacks'} '
        'contents: write',
      );
    }
    if (permissions is YamlMap) {
      final writes = permissions.entries.where((e) => e.value == 'write');
      final allowed = writers.contains(name)
          ? {'contents'}
          : name == 'attest'
          ? {'id-token', 'attestations'}
          : <String>{};
      if (writes.any((e) => !allowed.contains(e.key))) {
        problems.add('job $name writes beyond what it needs');
      }
    }
    for (final step in job['steps'] as YamlList) {
      step as YamlMap;
      final uses = step['uses'];
      if (uses is String && !_pinned.hasMatch(uses)) {
        problems.add('job $name uses $uses, not pinned by a commit SHA');
      }
      if (uses is String && !_allowedOwners.contains(uses.split('/').first)) {
        problems.add(
          'job $name uses $uses, whose owner the repository does '
          'not allow',
        );
      }
      if (uses is String &&
          uses.startsWith('actions/checkout@') &&
          (step['with'] as YamlMap?)?['persist-credentials'] != false) {
        problems.add('job $name checks out with persisted credentials');
      }
      final run = step['run'];
      if (run is String && run.contains('git ')) {
        if (run.contains('http.extraheader')) {
          if (RegExp(r'-c\s+\S*http\.extraheader').hasMatch(run)) {
            problems.add('job $name passes http.extraheader in argv');
          }
          if (!run.contains('::add-mask::')) {
            problems.add('job $name does not mask the derived header');
          }
          if (!run.contains('GIT_CONFIG_COUNT')) {
            problems.add('job $name does not pass the header through env');
          }
        }
        if (run.contains('cat-file') &&
            !run.contains(r'rev-parse "refs/tags/$TAG^{commit}"')) {
          problems.add('job $name does not assert HEAD is the tag commit');
        }
      }
      if (run is String && run.contains(r'${{')) {
        problems.add('job $name interpolates an expression into a run');
      }
    }
  }

  final env = workflow['env'] as YamlMap;
  if (!_hex64.hasMatch('${env['DART_SDK_SHA256']}') ||
      !RegExp(r'^\d+\.\d+\.\d+$').hasMatch('${env['DART_SDK_VERSION']}')) {
    problems.add(
      'the Dart SDK version or sha256 is not pinned at workflow '
      'level',
    );
  }
  for (final name in ['build', 'attach']) {
    final runs = [
      for (final step in (jobs[name] as YamlMap)['steps'] as YamlList)
        '${(step as YamlMap)['run']}',
    ];
    final install = runs.where((run) => run.contains('dartsdk-linux-arm64'));
    if (install.length != 1) {
      problems.add('job $name does not install the Dart SDK once');
      continue;
    }
    final run = install.single;
    final check = run.indexOf('sha256sum --check');
    final unzip = run.indexOf('unzip');
    if (check < 0 || unzip < 0 || check > unzip) {
      problems.add('job $name unzips the Dart SDK before checking its digest');
    }
    if (!run.contains(r'$DART_SDK_SHA256') || !run.contains(r'$RUNNER_TEMP')) {
      problems.add('job $name does not use the pinned digest in RUNNER_TEMP');
    }
    if (!run.contains(r'GITHUB_PATH') ||
        !run.contains(r'dart --version') ||
        !run.contains(r'Dart SDK version: $DART_SDK_VERSION')) {
      problems.add(
        'job $name does not add the SDK to the path and assert '
        'its version',
      );
    }
  }

  final inputs = (workflow['on'] as YamlMap)['workflow_dispatch']['inputs'];
  if (inputs['tag']['type'] != 'string') problems.add('tag is not a string');
  final options = inputs['platform']['options'] as YamlList;
  if (options.length != 1 || options.single != 'linux-arm64') {
    problems.add('platform is not the choice [linux-arm64]');
  }
  final firstRun = ((jobs['build'] as YamlMap)['steps'] as YamlList).first;
  if (!'${(firstRun as YamlMap)['run']}'.contains(
    r'^v[0-9]+\.[0-9]+\.[0-9]+$',
  )) {
    problems.add('the first step of build does not validate the tag');
  }
  final group = '${(workflow['concurrency'] as YamlMap)['group']}';
  if (!group.contains('inputs.tag') || !group.contains('inputs.platform')) {
    problems.add('concurrency is not per tag and platform');
  }
  return problems;
}

void main() {
  final source = File('.github/workflows/archives.yml').readAsStringSync();

  test('the workflow is pinned, least-privilege and injection-free', () {
    check(workflowProblems(source)).isEmpty();
  });

  for (final (label, from, to, problem) in [
    (
      'an unpinned action',
      RegExp(r'actions/attest@[0-9a-f]{40}'),
      'actions/attest@v4',
      'actions/attest@v4, not pinned',
    ),
    (
      'an action of an owner the repository does not allow',
      RegExp(r'actions/attest@'),
      'dart-lang/setup-dart@',
      'whose owner the repository does not allow',
    ),
    (
      'a Dart SDK unzipped before its digest is checked',
      RegExp(r'sha256sum --check'),
      'true',
      'unzips the Dart SDK before checking its digest',
    ),
    (
      'a Dart SDK version that is not asserted',
      RegExp(r'dart --version'),
      'dart --help',
      'does not add the SDK to the path and assert its version',
    ),
    (
      'an unpinned Dart SDK digest',
      RegExp(r'DART_SDK_SHA256: [0-9a-f]{64}'),
      'DART_SDK_SHA256: latest',
      'not pinned at workflow level',
    ),
    (
      'a short SHA',
      RegExp(r'actions/upload-artifact@[0-9a-f]{40}'),
      'actions/upload-artifact@cf430e0',
      'not pinned',
    ),
    (
      'non-empty top-level permissions',
      RegExp(r'^permissions: \{\}$', multiLine: true),
      'permissions:\n  contents: read',
      'top-level permissions are not empty',
    ),
    (
      'no top-level permissions',
      RegExp(r'^permissions: \{\}\n$', multiLine: true),
      '',
      'top-level permissions are not empty',
    ),
    (
      'contents: write on attest',
      RegExp(r'      contents: read\n      id-token'),
      '      contents: write\n      id-token',
      'job attest holds contents: write',
    ),
    (
      'attestations: write on build',
      RegExp(
        r'(  build:\n(?:.*\n)*?    permissions:\n      contents: write\n)',
      ),
      r'$1      attestations: write'
          '\n',
      'job build writes beyond',
    ),
    (
      'no write on attach',
      RegExp(r'(  attach:\n(?:.*\n)*?    permissions:\n      contents: )write'),
      r'$1read',
      'job attach lacks contents: write',
    ),
    (
      'persisted credentials',
      RegExp(r'          persist-credentials: false\n'),
      '',
      'persisted credentials',
    ),
    (
      'an input interpolated into run',
      RegExp(r'printf \x27%s\x27 "\$TAG" \| grep'),
      r'printf ${{ inputs.tag }} | grep',
      'interpolates an expression into a run',
    ),
    (
      'another platform choice',
      RegExp(r'          - linux-arm64\n'),
      '          - linux-arm64\n          - windows-x64\n',
      'platform is not the choice',
    ),
    (
      'a header passed in argv',
      RegExp(r'git fetch'),
      'git -c http.extraheader=x fetch',
      'passes http.extraheader in argv',
    ),
    (
      'an unmasked header',
      RegExp(r'echo "::add-mask::\$value"\n'),
      '',
      'does not mask the derived header',
    ),
    (
      'a missing HEAD assertion',
      RegExp(
        r'          test "\$\(git rev-parse "refs/tags/\$TAG\^\{commit\}"\)".*\n.*\n',
      ),
      '',
      'does not assert HEAD',
    ),
    (
      'a concurrency group without the tag',
      RegExp(r'group: archives-\$\{\{ inputs.tag \}\}-'),
      'group: archives-',
      'concurrency is not per tag and platform',
    ),
  ]) {
    test('the checker refuses $label', () {
      final mutated = source.replaceFirstMapped(
        from,
        (m) => to.replaceAll(r'$1', m.groupCount >= 1 ? m[1]! : ''),
      );
      check(mutated).not((it) => it.equals(source));

      final found = workflowProblems(mutated);

      check(found.any((p) => p.contains(problem)), because: '$found').isTrue();
    });
  }
}
