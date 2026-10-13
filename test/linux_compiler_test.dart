import 'dart:convert';
import 'dart:io';

import 'package:checks/checks.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../tool/src/build_platform.dart';
import '../tool/src/compiler.dart';

const _platform = BuildPlatform.linuxArm64;
const _clang = '/opt/llvm/bin/clang';
const _ld = '/usr/bin/aarch64-linux-gnu-ld.bfd';
const _clangVersion = 'clang version 21.1.8';
const _ldVersion = 'GNU ld (GNU Binutils for Ubuntu) 2.46';
const _dpkg = '/usr/bin/dpkg-query';
const _rpm = '/usr/bin/rpm';
const _ldPackage = 'binutils-aarch64-linux-gnu';

/// The bytes of a `libc.so.6` whose banner names [release], among others.
List<int> _libc(String release) => latin1.encode(
  '\x7fELF\x00\x00padding\x00GNU C Library (Ubuntu GLIBC $release-2ubuntu2) '
  'stable release version $release.\nCopyright (C) 2026\x00more\x00',
);

void main() {
  late Directory scratch;

  setUp(() => scratch = Directory.systemTemp.createTempSync('linux_compiler'));
  tearDown(() => scratch.deleteSync(recursive: true));

  group('resolveLinuxCompiler, on any host,', () {
    late String libc;
    late List<List<String>> asked;

    setUp(() {
      libc = p.join(scratch.path, 'lib', 'aarch64-linux-gnu', 'libc.so.6');
      File(libc)
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(_libc('2.43'));
      asked = [];
    });

    /// A [ToolRunner] answering as clang, GNU ld and dpkg answer on Ubuntu,
    /// with [answers] in place of any of their answers, keyed by the
    /// argument asked last, and failing as a tool that is not there for
    /// each of [missing].
    ToolRunner runner(
      Map<String, String> answers, {
      Set<String> missing = const {},
    }) => (executable, arguments) async {
      asked.add([executable, ...arguments]);
      if (missing.contains(executable)) {
        throw CompilerException('$executable: not found');
      }
      final key = arguments.last;
      if (answers[key] case final answer?) return answer;
      return switch ((executable, key)) {
        (_clang, '-print-file-name=libc.so.6') => libc,
        (_clang, '-print-prog-name=ld.bfd') => _ld,
        (_clang, '--version') => '$_clangVersion\nTarget: aarch64',
        (_ld, '--version') => '$_ldVersion\nCopyright (C) 2026',
        (_dpkg, _ld) => '$_ldPackage: $_ld',
        (_dpkg, _ldPackage) => '$_ldPackage 2.46-3ubuntu2',
        _ => throw CompilerException('unexpected $executable $arguments'),
      };
    };

    Future<Compiler> resolve([
      Map<String, String> answers = const {},
      Set<String> missing = const {_rpm},
    ]) => resolveLinuxCompiler(
      _platform,
      clang: _clang,
      run: runner(answers, missing: missing),
    );

    test('records clang, the GNU ld it links with and the C library it '
        'links against, each with its path', () async {
      final compiler = await resolve();

      check(compiler.path).equals(_clang);
      check(compiler.version).equals(_clangVersion);
      check(compiler.platform).equals(_platform);
      check(compiler.linker).equals(_ldVersion);
      check(compiler.linkerPackage).equals('$_ldPackage 2.46-3ubuntu2');
      check(compiler.linkerPath).equals(_ld);
      check(compiler.hostLibc).equals('glibc 2.43');
      check(compiler.hostLibcBanner).equals(
        'GNU C Library (Ubuntu GLIBC 2.43-2ubuntu2) stable release version '
        '2.43',
      );
      check(compiler.hostLibcPath).equals(libc);
      check(compiler.sdkPath).isNull();
      check(asked).deepEquals([
        [_clang, '--target=aarch64-linux-gnu', '-print-file-name=libc.so.6'],
        [_clang, '--target=aarch64-linux-gnu', '-print-prog-name=ld.bfd'],
        [_ld, '--version'],
        [_dpkg, '-S', _ld],
        [_dpkg, '-W', r'--showformat=${Package} ${Version}', _ldPackage],
        [_clang, '--version'],
      ]);
    });

    test('records the package and revision that installed the linker, '
        'which its --version leaves out', () async {
      // Diversions are named too, and an architecture-qualified package
      // is asked for as dpkg names it.
      final compiler = await resolve({
        _ld:
            'diversion by other from: $_ld\n'
            'diversion by other to: $_ld.real\n'
            'binutils:arm64: $_ld',
        'binutils:arm64': 'binutils 2.46-3ubuntu1',
      });

      check(compiler.linkerPackage).equals('binutils 2.46-3ubuntu1');
      check(asked).any(
        (it) => it.deepEquals([
          _dpkg,
          '-W',
          r'--showformat=${Package} ${Version}',
          'binutils:arm64',
        ]),
      );
    });

    test('asks rpm for the linker\'s package where there is no dpkg', () async {
      final compiler = await resolve({_ld: 'binutils 2.46-1.fc44'}, {_dpkg});

      check(compiler.linkerPackage).equals('binutils 2.46-1.fc44');
      check(asked).any(
        (it) => it.deepEquals([
          _rpm,
          '-qf',
          '--queryformat',
          '%{NAME} %{EVR}',
          _ld,
        ]),
      );
    });

    test('refuses a linker no package database names a package of', () async {
      for (final (answers, missing) in [
        (const <String, String>{}, {_dpkg, _rpm}),
        // dpkg would answer for the two packages as for one.
        (
          {
            _ld: 'binutils, binutils-x: $_ld',
            'binutils, binutils-x': 'binutils 2.46-3ubuntu2',
          },
          {_rpm},
        ),
        ({_ld: 'diversion by other from: $_ld'}, {_rpm}),
        ({_ldPackage: ''}, {_rpm}),
      ]) {
        await check(
          because: '$answers $missing',
          resolve(answers, missing),
        ).throws<CompilerException>(
          (it) => it
              .has((e) => e.message, 'message')
              .equals(
                'no package database names the one package that installed '
                '$_ld; a build on Linux records the binutils package and '
                'revision it links with',
              ),
        );
      }
    });

    test('reads the glibc release from the libc.so.6 clang links against, '
        'whatever glibc this process runs on', () async {
      final other = p.join(scratch.path, 'sysroot', 'libc.so.6');
      File(other)
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(_libc('2.39'));

      final compiler = await resolve({'-print-file-name=libc.so.6': other});

      check(compiler.hostLibc).equals('glibc 2.39');
      check(compiler.hostLibcPath).equals(other);
    });

    test('refuses the bare name clang answers when it finds no libc.so.6 '
        'for the target, or any relative path', () async {
      // pubspec.yaml names a file relative to the working directory the
      // tests run in, which a relative answer must not be read against.
      for (final answer in ['libc.so.6', 'pubspec.yaml']) {
        check(File(answer).existsSync()).equals(answer == 'pubspec.yaml');

        await check(
          because: answer,
          resolve({'-print-file-name=libc.so.6': answer}),
        ).throws<CompilerException>(
          (it) => it
              .has((e) => e.message, 'message')
              .equals(
                '$_clang finds no libc.so.6 for aarch64-linux-gnu; install '
                'the C library for that target',
              ),
        );
      }
    });

    test('refuses a libc.so.6 path that names no file', () async {
      await check(
        resolve({
          '-print-file-name=libc.so.6': p.join(scratch.path, 'libc.so.6'),
        }),
      ).throws<CompilerException>(
        (it) => it.has((e) => e.message, 'message').contains('finds no libc'),
      );
    });

    test('refuses a C library whose file names no glibc release', () async {
      for (final text in [
        'musl libc (aarch64)\nVersion 1.2.5\n',
        'GNU C Library (GNU libc) stable release version two.\n',
        '',
      ]) {
        File(libc).writeAsStringSync(text);

        await check(because: text, resolve()).throws<CompilerException>(
          (it) => it
              .has((e) => e.message, 'message')
              .equals(
                '$libc names no glibc release; a build on Linux links '
                'against glibc',
              ),
        );
      }
    });

    test(
      'refuses the bare name clang answers when it finds no ld.bfd',
      () async {
        await check(
          resolve({'-print-prog-name=ld.bfd': 'ld.bfd'}),
        ).throws<CompilerException>(
          (it) => it
              .has((e) => e.message, 'message')
              .equals(
                '$_clang finds no ld.bfd for aarch64-linux-gnu; install GNU '
                'binutils for that target',
              ),
        );
      },
    );

    test('refuses a linker that is not GNU ld', () async {
      await check(
        resolve({'--version': 'LLD 21.1.8 (compatible with GNU linkers)'}),
      ).throws<CompilerException>(
        (it) => it
            .has((e) => e.message, 'message')
            .startsWith('$_ld --version reports LLD 21.1.8'),
      );
    });
  });

  test('glibcBanner reads the banner of a libc.so.6, with its build', () {
    check(glibcBanner(_libc('2.43'))).equals(
      'GNU C Library (Ubuntu GLIBC 2.43-2ubuntu2) stable release version '
      '2.43',
    );
    check(glibcBanner(latin1.encode('release version 2.43.'))).isNull();
  });

  test('glibcRelease reads the release a libc.so.6 banner names', () {
    check(glibcRelease(_libc('2.43'))).equals('glibc 2.43');
    check(glibcRelease(_libc('2.3.4'))).equals('glibc 2.3.4');
    check(
      glibcRelease(
        latin1.encode(
          'GNU C Library (GNU libc) development release version 2.44.9000.',
        ),
      ),
    ).equals('glibc 2.44.9000');
    check(glibcRelease(latin1.encode('release version 2.43.'))).isNull();
  });

  group('onPath', () {
    void make(String directory, {required bool executable}) {
      final file = File(p.join(scratch.path, directory, 'clang'))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('#!/bin/sh\n');
      if (executable) Process.runSync('/bin/chmod', ['0755', file.path]);
    }

    String path(List<String> directories) => [
      for (final directory in directories) p.join(scratch.path, directory),
    ].join(':');

    test('passes over a file it cannot run and a directory of the name', () {
      make('plain', executable: false);
      Directory(
        p.join(scratch.path, 'folder', 'clang'),
      ).createSync(recursive: true);
      make('bin', executable: true);

      check(
        onPath('clang', _platform, path: path(['plain', 'folder', 'bin'])),
      ).equals(p.join(scratch.path, 'bin', 'clang'));
    });

    test('finds none when nothing of the name can be run', () {
      make('plain', executable: false);

      check(
        () => onPath('clang', _platform, path: path(['', 'plain'])),
      ).throws<CompilerException>();
    });
  }, testOn: '!windows');
}
