import 'dart:io';

import 'package:checks/checks.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

final _pinned = RegExp(r'^[\w.-]+/[\w./-]+@[0-9a-f]{40}$');

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
      if (uses is String &&
          uses.startsWith('actions/checkout@') &&
          (step['with'] as YamlMap?)?['persist-credentials'] != false) {
        problems.add('job $name checks out with persisted credentials');
      }
      final run = step['run'];
      if (run is String && run.contains(r'${{')) {
        problems.add('job $name interpolates an expression into a run');
      }
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
