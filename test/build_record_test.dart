import 'dart:convert';

import 'package:checks/checks.dart';
import 'package:test/test.dart';

import '../tool/src/build_record.dart';
import '../tool/src/compiler.dart';
import '../tool/src/toolchain.dart';

const _toolchain = Toolchain(
  treeSitterTag: 'v0.27.0',
  treeSitterCommit: '6070dbfefd326bd735e5683eb128cc1b57dad0c0',
  treeSitterFilesSha256:
      '8284859e50207152e5df621e49086ea169020c47ef342489f5f8c06b7082f2ea',
  cliVersion: '0.27.0',
  cliAsset: 'tree-sitter-macos-arm64.gz',
  cliSha256: '70f7573b2b2e5371a5b58cc5227d2ad981fd5374596b9874e770af486060774e',
  arch: 'arm64',
  deploymentTarget: '13.0',
);

const _compiler = Compiler(
  path: '/xcode/clang',
  version: 'Apple clang version 17.0.0 (clang-1700.3.19.1)',
  sdkPath: '/xcode/MacOSX26.0.sdk',
  sdkVersion: '26.0',
  sdkBuildVersion: '25A352',
);

const _environment = {'PATH': '/usr/bin:/bin:/usr/sbin:/sbin'};

/// The invocations a build of one grammar, json, makes: the runtime, the
/// grammar's parser, and its link.
List<CompileCommand> _commands(BuildFlags flags) {
  final compile = grammarCompileCommand(
    compiler: _compiler,
    flags: flags,
    directory: '/clone',
    includeDirectory: 'build/src/tree-sitter-json/src',
    source: 'build/src/tree-sitter-json/src/parser.c',
    object: 'build/obj/json/parser.o',
    environment: _environment,
  );
  return [
    runtimeCommand(
      compiler: _compiler,
      flags: flags,
      directory: '/clone/build/src/tree-sitter',
      output: '../../../output/libtree-sitter.dylib',
      environment: _environment,
    ),
    compile,
    grammarLinkCommand(
      compiler: _compiler,
      flags: flags,
      directory: '/clone',
      libraryName: 'json',
      objects: [compile.output],
      output: 'output/dylibs/json/libjson.dylib',
      environment: _environment,
    ),
  ];
}

/// What build_info.json records of json's own flags: its parser's include
/// directory and its install name.
Map<String, Map<String, List<String>>> _grammarFlags() => {
  'json': {
    'parser.c': grammarSourceFlags('build/src/tree-sitter-json/src'),
    'link': grammarLinkFlags('json'),
  },
};

/// build_info.json as the build writes it and a reader decodes it.
Map<String, Object?> _info(
  BuildFlags flags, {
  Map<String, Map<String, List<String>>>? grammarFlags,
}) =>
    jsonDecode(
          encodeBuildInfo(
            buildInfo(
              release: null,
              toolchain: _toolchain,
              compiler: _compiler,
              flags: flags,
              grammarFlags: grammarFlags ?? _grammarFlags(),
              repositoryCommit: '77ac13625d220bcf955cb12f697e438238c774e0',
              repositoryDirty: false,
              languageVersion: 15,
              minCompatibleLanguageVersion: 13,
              sources: const {},
              generated: const {},
              packingTools: const {
                'git': 'git version 2.50.1 (Apple Git-155)',
                'gzip': 'Apple gzip 457.140.3',
                'tar': 'bsdtar 3.5.3',
              },
            ),
          ),
        )
        as Map<String, Object?>;

/// [commands] after a JSON round trip, as the check reads them from disk.
List<CompileCommand> _roundTrip(List<CompileCommand> commands) =>
    parseCompileCommands(encodeCompileCommands(commands));

void main() {
  final flags = BuildFlags(_toolchain, _compiler);

  test('the compile lists pass -O3 once, the link list none, none NDEBUG', () {
    for (final list in [flags.runtime, flags.grammarCompile]) {
      check(list.where((flag) => flag.startsWith('-O'))).deepEquals(['-O3']);
    }
    check(flags.grammarLink.where((flag) => flag.startsWith('-O'))).isEmpty();
    for (final list in [
      flags.runtime,
      flags.grammarCompile,
      flags.grammarLink,
    ]) {
      check(list.where((flag) => flag.contains('NDEBUG'))).isEmpty();
      check(list).contains('-mmacosx-version-min=13.0');
    }
  });

  test('build_info records the tools that write the bundles', () {
    final toolchain = _info(flags)['toolchain']! as Map<String, Object?>;

    check(toolchain['git']).equals('git version 2.50.1 (Apple Git-155)');
    check(toolchain['gzip']).equals('Apple gzip 457.140.3');
    check(toolchain['tar']).equals('bsdtar 3.5.3');
  });

  test('invocations built from the flags match what build_info records', () {
    final commands = _roundTrip(_commands(flags));

    check(buildFlagProblems(_info(flags), commands, {'json'})).isEmpty();
    check(
      commands[1].arguments.take(3),
    ).deepEquals(['/xcode/clang', '-c', '-O3']);
    check(commands[1].arguments).contains('-ffile-prefix-map=/clone=.');
  });

  test('an invocation passing a flag the record lacks is reported', () {
    final commands = _commands(flags);
    final compile = commands[1];
    final mutated = CompileCommand(
      directory: compile.directory,
      arguments: [...compile.arguments]..insert(2, '-DNDEBUG'),
      output: compile.output,
      environment: compile.environment,
    );

    check(
      buildFlagProblems(
        _info(flags),
        [commands[0], mutated, commands[2]],
        {'json'},
      ),
    ).deepEquals([
      'build/obj/json/parser.o: arguments do not start with the recorded '
          'grammarCompile flags and its own',
    ]);
  });

  test('build_info records the include directory and install name of '
      'each grammar', () {
    final grammars =
        ((_info(flags)['toolchain']! as Map)['flags']! as Map)['grammars'];

    check(grammars).isA<Map<String, Object?>>().deepEquals({
      'json': {
        'parser.c': ['-I', 'build/src/tree-sitter-json/src'],
        'link': ['-Wl,-install_name,@rpath/libjson.dylib'],
      },
    });
  });

  test('a compile against another include directory is reported', () {
    final info = _info(
      flags,
      grammarFlags: {
        'json': {
          'parser.c': grammarSourceFlags('build/gen/json'),
          'link': grammarLinkFlags('json'),
        },
      },
    );

    check(buildFlagProblems(info, _commands(flags), {'json'})).deepEquals([
      'build/obj/json/parser.o: arguments do not start with the recorded '
          'grammarCompile flags and its own',
    ]);
  });

  test('a link under another install name is reported', () {
    final info = _info(
      flags,
      grammarFlags: {
        'json': {
          'parser.c': grammarSourceFlags('build/src/tree-sitter-json/src'),
          'link': grammarLinkFlags('yaml'),
        },
      },
    );

    check(buildFlagProblems(info, _commands(flags), {'json'})).deepEquals([
      'output/dylibs/json/libjson.dylib: arguments do not start with the '
          'recorded grammarLink flags and its own',
      'json: never linked',
      '0 links for 1 grammars',
    ]);
  });

  test('a link recorded and run under another file\'s install name is '
      'reported', () {
    final commands = _commands(flags);
    final link = grammarLinkCommand(
      compiler: _compiler,
      flags: flags,
      directory: '/clone',
      libraryName: 'yaml',
      objects: [commands[1].output],
      output: 'output/dylibs/json/libjson.dylib',
      environment: _environment,
    );
    final info = _info(
      flags,
      grammarFlags: {
        'json': {..._grammarFlags()['json']!, 'link': grammarLinkFlags('yaml')},
      },
    );

    check(
      buildFlagProblems(info, [commands[0], commands[1], link], {'json'}),
    ).deepEquals([
      'output/dylibs/json/libjson.dylib: its recorded flags name no install '
          'name -Wl,-install_name,@rpath/libjson.dylib',
    ]);
  });

  test('a recorded source no invocation compiled is reported', () {
    final info = _info(
      flags,
      grammarFlags: {
        'json': {
          ..._grammarFlags()['json']!,
          'scanner.c': grammarSourceFlags('build/src/tree-sitter-json/src'),
        },
      },
    );

    check(
      buildFlagProblems(info, _commands(flags), {'json'}),
    ).deepEquals(['json: no invocation passed its scanner.c flags']);
  });

  test('a grammar with no record, or a record with -O0, is reported', () {
    check(
      buildFlagProblems(_info(flags, grammarFlags: {}), _commands(flags), {
        'json',
      }),
    ).deepEquals([
      'json: build_info.json records no flags of its own',
      'build/obj/json/parser.o: build_info.json records no parser.c flags '
          'of json',
      'output/dylibs/json/libjson.dylib: build_info.json records no link '
          'flags of json',
      'json: never linked',
      '0 links for 1 grammars',
    ]);
    final info = _info(
      flags,
      grammarFlags: {
        'json': {
          'parser.c': ['-O0', ...grammarSourceFlags('x')],
          'link': grammarLinkFlags('json'),
        },
      },
    );
    check(
      buildFlagProblems(info, _commands(flags), {'json'}),
    ).contains('json: its parser.c flags pass -O0');
  });

  test('a record without -O3 or with NDEBUG is reported', () {
    final info = _info(flags);
    final recorded = ((info['toolchain']! as Map)['flags']! as Map);
    recorded['runtime'] = [
      for (final flag in flags.runtime) flag == '-O3' ? '-O2' : flag,
    ];
    recorded['grammarCompile'] = [...flags.grammarCompile, '-DNDEBUG'];

    check(
      buildFlagProblems(info, _commands(flags), {'json'}),
    ).contains('runtime flags pass optimisation levels [-O2], not [-O3]');
    check(
      buildFlagProblems(info, _commands(flags), {'json'}),
    ).contains('grammarCompile flags pass -DNDEBUG');
  });

  test('an environment carrying CFLAGS is reported', () {
    final commands = _commands(flags);
    final runtime = commands.first;
    final leaky = CompileCommand(
      directory: runtime.directory,
      arguments: runtime.arguments,
      output: runtime.output,
      environment: {...runtime.environment, 'CFLAGS': '-O0'},
    );

    check(
      buildFlagProblems(_info(flags), [leaky, ...commands.skip(1)], {'json'}),
    ).deepEquals([
      '../../../output/libtree-sitter.dylib: environment has CFLAGS',
    ]);
  });

  test('a grammar that was never linked is reported', () {
    check(
      buildFlagProblems(_info(flags), _commands(flags), {'json', 'c'}),
    ).deepEquals([
      'c: build_info.json records no flags of its own',
      'c: never linked',
      '1 links for 2 grammars',
    ]);
  });

  group('repositoryRecordProblems', () {
    Map<String, Object?> record({String? release, Object? dirty = false}) => {
      ..._info(flags),
      'release': release,
      'repository': {
        'url': repositoryUrl,
        'commit': '77ac13625d220bcf955cb12f697e438238c774e0',
        'dirty': dirty,
      },
    };

    test('accepts a clean release and a dirty build that is none', () {
      check(repositoryRecordProblems(record(release: 'v1.1.0'))).isEmpty();
      check(repositoryRecordProblems(record(dirty: true))).isEmpty();
    });

    test('refuses a release built from a dirty working tree', () {
      check(
        repositoryRecordProblems(record(release: 'v1.1.0', dirty: true)),
      ).deepEquals([
        'build_info.json records the release v1.1.0 as built from a dirty '
            'working tree',
      ]);
    });

    test('refuses a release that does not record the tree at all', () {
      check(
        repositoryRecordProblems(record(release: 'v1.1.0', dirty: null)),
      ).deepEquals([
        'build_info.json does not record whether the working tree was dirty',
        'build_info.json records the release v1.1.0 as built from a dirty '
            'working tree',
      ]);
    });

    test('refuses a record naming no commit or another repository', () {
      final info = record()
        ..['repository'] = {
          'url': 'https://example.com/fork',
          'commit': 'HEAD',
          'dirty': false,
        };

      check(repositoryRecordProblems(info)).deepEquals([
        'build_info.json names the repository https://example.com/fork, not '
            '$repositoryUrl',
        'build_info.json records no 40-hex repository commit',
      ]);
    });
  });

  test(
    'the compiler environment keeps only PATH, TMPDIR and DEVELOPER_DIR',
    () {
      final environment = compilerEnvironment({
        'PATH': '/opt/homebrew/bin:/usr/bin',
        'TMPDIR': '/tmp/x/',
        'CFLAGS': '-O0',
        'CPPFLAGS': '-DNDEBUG',
        'LDFLAGS': '-Wl,-x',
        'CCC_OVERRIDE_OPTIONS': '+-O0',
        'SDKROOT': '/elsewhere',
      });

      check(environment).deepEquals({
        'PATH': '/usr/bin:/bin:/usr/sbin:/sbin',
        'TMPDIR': '/tmp/x/',
      });
    },
  );
}
