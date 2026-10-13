import 'dart:convert';
import 'dart:io';

import 'package:checks/checks.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../tool/src/build_platform.dart';
import '../tool/src/compiler.dart';

const _platform = BuildPlatform.linuxArm64;
const _clang = '/opt/llvm/bin/clang';
const _clangVersion = 'clang version 21.1.8';
const _ldVersion = 'GNU ld (GNU Binutils for Ubuntu) 2.46';
const _dpkg = '/usr/bin/dpkg-query';
const _rpm = '/usr/bin/rpm';
const _ldPackage = 'binutils-aarch64-linux-gnu';
const _devPackage = 'libc6-dev:arm64';
const _gccPackage = 'libgcc-15-dev:arm64';

/// [path] with every symbolic link resolved on a host with merged `/usr`,
/// where `/lib`, `/bin` and `/sbin` link to their directories under `/usr`.
String _merged(String path) => switch (p.posix.split(path)) {
  ['/', 'lib' || 'bin' || 'sbin', ...] => p.posix.join(
    '/usr',
    path.substring(1),
  ),
  _ => path,
};

/// Whether `/bin` on this host is a symbolic link to `/usr/bin`.
final _mergedUsr = (() {
  try {
    return Directory('/bin').resolveSymbolicLinksSync() == '/usr/bin';
  } on FileSystemException {
    return false;
  }
})();

/// The bytes of a `libc.so.6` whose banner names [release], among others.
List<int> _libc(String release) => latin1.encode(
  '\x7fELF\x00\x00padding\x00GNU C Library (Ubuntu GLIBC $release-2ubuntu2) '
  'stable release version $release.\nCopyright (C) 2026\x00more\x00',
);

/// What `clang -###` writes to its standard error for a link whose
/// arguments end with `<object> -o <output>`: its version lines, then the
/// one command it would run, every argument quoted as clang quotes it,
/// with [linker] first, [startup] for the C library's startup files and
/// [gcc] for GCC's.
String _driverOutput(
  List<String> arguments, {
  required String linker,
  required String startup,
  required String gcc,
}) {
  String quoted(String argument) =>
      '"${argument.replaceAllMapped(RegExp(r'["\\$]'), (m) => '\\${m[0]}')}"';
  final object = arguments[arguments.length - 3];
  final output = arguments.last;
  return [
    'Ubuntu clang version 21.1.8 (6ubuntu1)',
    'Target: aarch64-unknown-linux-gnu',
    'Thread model: posix',
    'InstalledDir: /usr/lib/llvm-21/bin',
    ' ${[linker, '-EL', '-shared', '-o', output, p.join(startup, 'crti.o'), p.join(gcc, 'crtbeginS.o'), '-L$gcc', '-z', 'defs', '-soname', 'libprobe.so', object, '-lgcc', '-lc', '-lgcc', p.join(gcc, 'crtendS.o'), p.join(startup, 'crtn.o')].map(quoted).join(' ')}',
  ].join('\n');
}

void main() {
  late Directory scratch;

  setUp(
    () => scratch = Directory(
      Directory.systemTemp
          .createTempSync('linux_compiler')
          .resolveSymbolicLinksSync(),
    ),
  );
  tearDown(() => scratch.deleteSync(recursive: true));

  group('resolveLinuxCompiler, on any host,', () {
    late String libc;
    // GNU ld as the -### link names it, and its file.
    late String ld;
    // A symbolic link to [ld], as /usr/bin/ld.bfd is on Ubuntu.
    late String ldLink;
    // The directory the link names the startup files in, through a
    // symbolic link as /lib is to usr/lib, and where they are.
    late String startup;
    late String crti;
    // The directory the link names GCC's startup files in, and the one it
    // starts each library with.
    late String gcc;
    late String crtbegin;
    late List<List<String>> asked;
    late List<String> probes;

    setUp(() {
      libc = p.join(scratch.path, 'lib', 'aarch64-linux-gnu', 'libc.so.6');
      File(libc)
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(_libc('2.43'));
      ld = p.join(scratch.path, 'bin', 'aarch64-linux-gnu-ld.bfd');
      File(ld)
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('');
      ldLink = p.join(scratch.path, 'bin', 'ld.bfd');
      Link(ldLink).createSync('aarch64-linux-gnu-ld.bfd');
      crti = p.join(scratch.path, 'usr', 'lib', 'aarch64-linux-gnu', 'crti.o');
      File(crti)
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('');
      Link(p.join(scratch.path, 'lib64')).createSync('usr/lib');
      startup = p.join(scratch.path, 'lib64', 'aarch64-linux-gnu');
      gcc = p.join(
        scratch.path,
        'usr',
        'lib',
        'gcc',
        'aarch64-linux-gnu',
        '15',
      );
      crtbegin = p.join(gcc, 'crtbeginS.o');
      for (final name in ['crtbeginS.o', 'crtendS.o', 'libgcc.a']) {
        File(p.join(gcc, name))
          ..parent.createSync(recursive: true)
          ..writeAsStringSync('');
      }
      asked = [];
      probes = [];
    });

    /// A [ToolRunner] answering as clang, GNU ld and dpkg answer on Ubuntu,
    /// with [answers] in place of any of their answers, keyed by the
    /// argument asked last, or `-###` for the link clang would run, and
    /// failing as a tool that is not there for each of [missing]. An
    /// answer is a string, or a function of the arguments.
    ToolRunner runner(
      Map<String, Object> answers, {
      Set<String> missing = const {},
    }) => (executable, arguments, {standardError = false}) async {
      asked.add([executable, ...arguments]);
      if (missing.contains(executable)) {
        throw CompilerException('$executable: not found');
      }
      final key = arguments.first == '-###' ? '-###' : arguments.last;
      if (key == '-###') {
        check(standardError).isTrue();
        final object = arguments[arguments.length - 3];
        check(File(object).existsSync()).isTrue();
        probes.add(object);
      } else {
        check(standardError).isFalse();
      }
      switch (answers[key]) {
        case final String answer:
          return answer;
        case final String Function(List<String>) answer:
          return answer(arguments);
      }
      return switch ((executable, key)) {
        (_clang, '-print-file-name=libc.so.6') => libc,
        (_clang, '-###') => _driverOutput(
          arguments,
          linker: ld,
          startup: startup,
          gcc: gcc,
        ),
        (_clang, '--version') => '$_clangVersion\nTarget: aarch64',
        (final tool, '--version') when tool == ld || tool == ldLink =>
          '$_ldVersion\nCopyright (C) 2026',
        (_dpkg, final path) when path == ld => '$_ldPackage: $ld',
        (_dpkg, final path) when path == crti => '$_devPackage: $crti',
        (_dpkg, final path) when path == crtbegin => '$_gccPackage: $crtbegin',
        (_dpkg, _ldPackage) => '$_ldPackage 2.46-3ubuntu2',
        (_dpkg, _devPackage) => 'libc6-dev 2.43-2ubuntu2',
        (_dpkg, _gccPackage) => 'libgcc-15-dev 15.2.0-16ubuntu1',
        _ => throw CompilerException('unexpected $executable $arguments'),
      };
    };

    Future<Compiler> resolve([
      Map<String, Object> answers = const {},
      Set<String> missing = const {_rpm},
    ]) => resolveLinuxCompiler(
      _platform,
      clang: _clang,
      run: runner(answers, missing: missing),
    );

    /// The answer of a `-###` link that runs [linker], with the C
    /// library's startup files in [startupDirectory] and GCC's in
    /// [gccDirectory], by default where they are.
    String Function(List<String>) linking(
      String linker, {
      String? startupDirectory,
      String? gccDirectory,
    }) =>
        (arguments) => _driverOutput(
          arguments,
          linker: linker,
          startup: startupDirectory ?? startup,
          gcc: gccDirectory ?? gcc,
        );

    test('records clang, the GNU ld it links with, the C library it '
        'links against and the packages of its startup files and of '
        'GCC\'s, each with its path', () async {
      final compiler = await resolve();

      check(compiler.path).equals(_clang);
      check(compiler.version).equals(_clangVersion);
      check(compiler.platform).equals(_platform);
      check(compiler.linker).equals(_ldVersion);
      check(compiler.linkerPackage).equals('$_ldPackage 2.46-3ubuntu2');
      check(compiler.linkerPath).equals(ld);
      check(compiler.linkerResolvedPath).equals(ld);
      check(compiler.hostLibc).equals('glibc 2.43');
      check(compiler.hostLibcBanner).equals(
        'GNU C Library (Ubuntu GLIBC 2.43-2ubuntu2) stable release version '
        '2.43',
      );
      check(compiler.hostLibcPath).equals(libc);
      check(compiler.hostLibcDev).equals('libc6-dev 2.43-2ubuntu2');
      check(compiler.hostLibcDevPath).equals(crti);
      check(compiler.gccRuntime).equals('libgcc-15-dev 15.2.0-16ubuntu1');
      check(compiler.gccRuntimePath).equals(crtbegin);
      check(compiler.sdkPath).isNull();
      final [object] = probes;
      final library = p.join(p.dirname(object), 'libprobe.so');
      check(asked).deepEquals([
        [_clang, '--target=aarch64-linux-gnu', '-print-file-name=libc.so.6'],
        [
          _clang,
          '-###',
          '-shared',
          '--target=aarch64-linux-gnu',
          '-fuse-ld=bfd',
          '-Wl,-z,defs',
          '-Wl,-soname,libprobe.so',
          object,
          '-o',
          library,
        ],
        [ld, '--version'],
        [_dpkg, '-S', ld],
        [_dpkg, '-W', r'--showformat=${Package} ${Version}', _ldPackage],
        [_dpkg, '-S', crti],
        [_dpkg, '-W', r'--showformat=${Package} ${Version}', _devPackage],
        [_dpkg, '-S', crtbegin],
        [_dpkg, '-W', r'--showformat=${Package} ${Version}', _gccPackage],
        [_clang, '--version'],
      ]);
      // The probe's directory is gone once clang has answered.
      check(Directory(p.dirname(object)).existsSync()).isFalse();
    });

    test('takes the linker from the link clang would run, not from '
        '-print-prog-name, which may search another way', () async {
      final compiler = await resolve({
        '-print-prog-name=ld.bfd': '/usr/bin/ld.bfd',
      });

      check(compiler.linkerPath).equals(ld);
      check(
        asked.where((it) => it.last.startsWith('-print-prog-name')),
      ).isEmpty();
    });

    test('records the linker by its normalised path, and asks the package '
        'database for the file it names with symbolic links resolved, '
        'which dpkg knows', () async {
      // clang names GNU ld relative to its GCC installation, through a
      // symbolic link, and the startup files through /lib, a link to
      // usr/lib; dpkg knows each file only by its own path.
      final named = p.join(
        scratch.path,
        'gcc',
        'aarch64-linux-gnu',
        '15',
        '..',
        '..',
        '..',
        'bin',
        'ld.bfd',
      );
      Directory(
        p.join(scratch.path, 'gcc', 'aarch64-linux-gnu', '15'),
      ).createSync(recursive: true);
      final compiler = await resolve({'-###': linking(named)});

      check(compiler.linkerPath).equals(ldLink);
      check(compiler.linkerResolvedPath).equals(ld);
      check(compiler.linkerPackage).equals('$_ldPackage 2.46-3ubuntu2');
      check(compiler.hostLibcDevPath).equals(crti);
      check(asked).any((it) => it.deepEquals([ldLink, '--version']));
      check([
        for (final it in asked)
          if (it[0] == _dpkg && it[1] == '-S') it.last,
      ]).deepEquals([ld, crti, crtbegin]);
    });

    test('refuses a linker path whose normalised form names another file '
        'than clang would run', () async {
      // Through a symbolic link, `..` leaves the directory the link
      // names, not the one it sits in.
      final elsewhere = p.join(scratch.path, 'elsewhere', 'bin');
      File(p.join(elsewhere, 'ld.bfd'))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('');
      Directory(p.join(scratch.path, 'tools')).createSync();
      Link(
        p.join(scratch.path, 'tools', 'gcc'),
      ).createSync(p.join(scratch.path, 'elsewhere', 'lib'));
      Directory(p.join(scratch.path, 'elsewhere', 'lib')).createSync();
      final named = p.join(scratch.path, 'tools', 'gcc', '..', 'bin', 'ld.bfd');
      File(p.join(scratch.path, 'tools', 'bin', 'ld.bfd'))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('');

      await check(resolve({'-###': linking(named)})).throws<CompilerException>(
        (it) => it
            .has((e) => e.message, 'message')
            .equals(
              '$_clang would link with $named, another file than its '
              'normalised path ${p.join(scratch.path, 'tools', 'bin', 'ld.bfd')} '
              'names',
            ),
      );
    });

    test('records the package and revision that installed the linker, '
        'which its --version leaves out', () async {
      // Diversions are named too, and an architecture-qualified package
      // is asked for as dpkg names it.
      final compiler = await resolve({
        ld:
            'diversion by other from: $ld\n'
            'diversion by other to: $ld.real\n'
            'binutils:arm64: $ld',
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
      final compiler = await resolve(
        {
          ld: 'binutils 2.46-1.fc44',
          crti: 'glibc-devel 2.43-1.fc44',
          crtbegin: 'gcc 15.2.1-1.fc44',
        },
        {_dpkg},
      );

      check(compiler.linkerPackage).equals('binutils 2.46-1.fc44');
      check(compiler.hostLibcDev).equals('glibc-devel 2.43-1.fc44');
      check(compiler.gccRuntime).equals('gcc 15.2.1-1.fc44');
      check(asked).any(
        (it) =>
            it.deepEquals([_rpm, '-qf', '--queryformat', '%{NAME} %{EVR}', ld]),
      );
    });

    test('refuses a linker no package database names a package of', () async {
      for (final (answers, missing) in [
        (const <String, Object>{}, {_dpkg, _rpm}),
        // dpkg would answer for the two packages as for one.
        (
          {
            ld: 'binutils, binutils-x: $ld',
            'binutils, binutils-x': 'binutils 2.46-3ubuntu2',
          },
          {_rpm},
        ),
        ({ld: 'diversion by other from: $ld'}, {_rpm}),
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
                '$ld; a build on Linux records the binutils package and '
                'revision it links with',
              ),
        );
      }
    });

    test('refuses startup files no package database names a package '
        'of', () async {
      await check(resolve({crti: ''})).throws<CompilerException>(
        (it) => it
            .has((e) => e.message, 'message')
            .equals(
              'no package database names the one package that installed '
              '$crti; a build on Linux records the package and revision of '
              'the C library\'s startup files it links',
            ),
      );
    });

    test('refuses a link clang would run that names no startup file, one '
        'that is not there, or two', () async {
      final other = p.join(scratch.path, 'other', 'crti.o');
      File(other)
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('');
      for (final answer in [
        (List<String> arguments) =>
            linking(ld)(arguments).replaceAll(RegExp(r'"[^"]*crti\.o" '), ''),
        (List<String> arguments) =>
            linking(ld)(arguments).replaceFirst('"-shared"', '"$other"'),
        linking(ld, startupDirectory: p.join(scratch.path, 'nowhere')),
        linking(ld, startupDirectory: 'lib'),
      ]) {
        await check(resolve({'-###': answer})).throws<CompilerException>(
          (it) => it
              .has((e) => e.message, 'message')
              .startsWith('the link $_clang would run names no one crti.o'),
        );
      }
    });

    test('refuses GCC\'s startup files no package database names a '
        'package of', () async {
      await check(resolve({crtbegin: ''})).throws<CompilerException>(
        (it) => it
            .has((e) => e.message, 'message')
            .equals(
              'no package database names the one package that installed '
              '$crtbegin; a build on Linux records the package and revision '
              'of GCC\'s startup files and libgcc it links',
            ),
      );
    });

    test('refuses a link clang would run that names no crtbeginS.o of '
        'GCC, one that is not there, or two', () async {
      final other = p.join(scratch.path, 'other', 'crtbeginS.o');
      File(other)
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('');
      for (final answer in [
        (List<String> arguments) => linking(ld)(
          arguments,
        ).replaceAll(RegExp(r'"[^"]*crtbeginS\.o" '), ''),
        (List<String> arguments) =>
            linking(ld)(arguments).replaceFirst('"-shared"', '"$other"'),
        linking(ld, gccDirectory: p.join(scratch.path, 'nowhere')),
        linking(ld, gccDirectory: 'gcc'),
      ]) {
        await check(resolve({'-###': answer})).throws<CompilerException>(
          (it) => it
              .has((e) => e.message, 'message')
              .startsWith(
                'the link $_clang would run names no one crtbeginS.o',
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

    test('refuses a link clang would run by the bare name of a linker, or '
        'by one that is not there', () async {
      // pubspec.yaml names a file relative to the working directory the
      // tests run in, which a relative answer must not be read against.
      for (final linker in [
        'ld.bfd',
        'pubspec.yaml',
        p.join(scratch.path, 'bin', 'ld'),
        p.join(scratch.path, 'bin'),
      ]) {
        await check(
          because: linker,
          resolve({'-###': linking(linker)}),
        ).throws<CompilerException>(
          (it) => it
              .has((e) => e.message, 'message')
              .equals(
                '$_clang would link with $linker, which is no file; install '
                'GNU binutils for aarch64-linux-gnu',
              ),
        );
      }
    });

    test('refuses an answer to -### that runs no link, or more than '
        'one', () async {
      for (final answer in [
        'clang version 21.1.8\nTarget: aarch64-unknown-linux-gnu',
        (List<String> arguments) =>
            '${linking(ld)(arguments)}\n "$ld" "-o" "x"',
        // A link of other objects than the probe's.
        (List<String> arguments) => linking(ld)(
          arguments,
        ).replaceAll(arguments[arguments.length - 3], 'other.o'),
      ]) {
        await check(resolve({'-###': answer})).throws<CompilerException>(
          (it) => it
              .has((e) => e.message, 'message')
              .startsWith('$_clang -### names no one link of '),
        );
      }
    });

    test('refuses a linker that is not GNU ld', () async {
      await check(
        resolve({'--version': 'LLD 21.1.8 (compatible with GNU linkers)'}),
      ).throws<CompilerException>(
        (it) => it
            .has((e) => e.message, 'message')
            .startsWith('$ld --version reports LLD 21.1.8'),
      );
    });
  });

  group('packageOf', () {
    late List<List<String>> asked;

    setUp(() => asked = []);

    /// A [ToolRunner] answering as dpkg answers on a host whose package
    /// database names files by [owners], each path to the line `dpkg-query
    /// -S` writes for it, and each package to its name and version; a
    /// path or package it does not hold fails, as dpkg does. rpm is not
    /// there unless [rpm] answers for the paths it names.
    ToolRunner dpkg(Map<String, String> owners, {Map<String, String>? rpm}) =>
        (executable, arguments, {standardError = false}) async {
          asked.add([executable, ...arguments]);
          final key = arguments.last;
          final answer = switch (executable) {
            _dpkg => owners[key],
            _rpm =>
              rpm == null
                  ? throw CompilerException('$_rpm: not found')
                  : rpm[key],
            _ => null,
          };
          if (answer == null) {
            throw CompilerException('$executable: no path found matching $key');
          }
          return answer;
        };

    test('asks for the /lib, /bin or /sbin name of a file under /usr that '
        'no package database names by its own, the same file on a host '
        'with merged /usr', () async {
      for (final (directory, package) in [
        ('lib/aarch64-linux-gnu', 'libc6-dev:arm64'),
        ('bin', 'binutils'),
        ('sbin', 'ldconfig'),
      ]) {
        asked = [];
        final path = '/usr/$directory/file';
        final alias = '/$directory/file';
        final run = dpkg({
          alias: '$package: $alias',
          package: '$package 1.0-1',
        });

        check(
          because: path,
          await packageOf(path, run, resolve: _merged),
        ).equals('$package 1.0-1');
        check(because: path, asked).deepEquals([
          [_dpkg, '-S', path],
          [_rpm, '-qf', '--queryformat', '%{NAME} %{EVR}', path],
          [_dpkg, '-S', alias],
          [_dpkg, '-W', r'--showformat=${Package} ${Version}', package],
        ]);
      }
    });

    test('asks rpm for the /usr-less name where there is no dpkg', () async {
      final run = dpkg(const {}, rpm: {'/lib/crti.o': 'glibc-devel 2.17-1'});

      check(
        await packageOf('/usr/lib/crti.o', run, resolve: _merged),
      ).equals('glibc-devel 2.17-1');
      check(asked.map((it) => it.last)).deepEquals([
        '/usr/lib/crti.o',
        '/usr/lib/crti.o',
        '/lib/crti.o',
        '/lib/crti.o',
      ]);
    });

    test('asks for no other name of a file its own name is known by', () async {
      const path = '/usr/bin/ld.bfd';
      final run = dpkg({
        path: 'binutils: $path',
        '/bin/ld.bfd': 'other: /bin/ld.bfd',
        'binutils': 'binutils 2.46-3',
      });

      check(
        await packageOf(path, run, resolve: _merged),
      ).equals('binutils 2.46-3');
      check(asked.map((it) => it.last)).deepEquals([path, 'binutils']);
    });

    test('asks for no other name of a file outside /usr/lib, /usr/bin and '
        '/usr/sbin', () async {
      for (final path in [
        '/opt/llvm/bin/ld.lld',
        '/usr/libexec/gcc/ld',
        '/usr/lib64/crti.o',
        '/usr/local/bin/ld',
        '/usr/ld',
        '/usr',
      ]) {
        asked = [];
        final run = dpkg({
          for (final alias in ['/libexec/gcc/ld', '/lib64/crti.o', '/ld'])
            alias: 'other: $alias',
          'other': 'other 1.0-1',
        });

        check(
          because: path,
          await packageOf(path, run, resolve: _merged),
        ).isNull();
        check(
          because: path,
          asked.map((it) => it.last),
        ).deepEquals([path, path]);
      }
    });

    test('asks for the /bin name of a file under /usr/bin on this host with '
        'merged /usr', () async {
      // A file /usr/bin holds itself, no symbolic link.
      final path = Directory(
        '/usr/bin',
      ).listSync(followLinks: false).whereType<File>().first.path;
      final alias = '/bin/${p.basename(path)}';
      final run = dpkg({alias: 'other: $alias', 'other': 'other 1.0-1'});

      check(await packageOf(path, run)).equals('other 1.0-1');
      check(
        asked.map((it) => it.last),
      ).deepEquals([path, path, alias, 'other']);
    }, skip: _mergedUsr ? false : 'this host has no merged /usr');

    test('names no package of a file by a /lib, /bin or /sbin name that is '
        'no file', () async {
      // Neither name is a file on any host the tests run on.
      const path = '/usr/bin/zz-tree-sitter-grammars-no-such-file';
      const alias = '/bin/zz-tree-sitter-grammars-no-such-file';
      final run = dpkg({alias: 'other: $alias', 'other': 'other 1.0-1'});

      check(await packageOf(path, run)).isNull();
      check(asked.map((it) => it.last)).deepEquals([path, path]);
    });

    test('names no package of a file by a /lib, /bin or /sbin name that is '
        'another file, as on a host without merged /usr', () async {
      for (final (because, resolved) in [
        ('another file', '/lib/crti.o'),
        ('another file under /usr', '/usr/lib/other/crti.o'),
        ('no file', null),
      ]) {
        asked = [];
        final run = dpkg({
          '/lib/crti.o': 'other: /lib/crti.o',
          'other': 'other 1.0-1',
        });

        check(
          because: because,
          await packageOf(
            '/usr/lib/crti.o',
            run,
            resolve: (it) => it == '/lib/crti.o' ? resolved : it,
          ),
        ).isNull();
        check(
          because: because,
          asked.map((it) => it.last),
        ).deepEquals(['/usr/lib/crti.o', '/usr/lib/crti.o']);
      }
    });

    test('names no package of a file no package database names by either '
        'name', () async {
      check(
        await packageOf('/usr/lib/crti.o', dpkg(const {}), resolve: _merged),
      ).isNull();
      check(asked.map((it) => it.last)).deepEquals([
        '/usr/lib/crti.o',
        '/usr/lib/crti.o',
        '/lib/crti.o',
        '/lib/crti.o',
      ]);
    });
  });

  group('driverCommands', () {
    test('reads each command clang -### would run, unquoted', () {
      check(
        driverCommands(
          'clang version 18.1.8\n'
          'InstalledDir: /usr/lib/llvm-18/bin\n'
          ' "/usr/bin/aarch64-linux-gnu-ld.bfd" "-z" "relro" '
          r'"a \"quoted\" \\ \$name" "o.so"'
          '\n'
          ' "/usr/bin/true" ""',
        ),
      ).deepEquals([
        [
          '/usr/bin/aarch64-linux-gnu-ld.bfd',
          '-z',
          'relro',
          r'a "quoted" \ $name',
          'o.so',
        ],
        ['/usr/bin/true', ''],
      ]);
      check(
        driverCommands('clang version 18.1.8\nThread model: posix'),
      ).isEmpty();
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

    test('takes a file with an execute bit for anyone, and passes over one '
        'with none', () {
      for (final (mode, runnable) in [
        ('0755', true),
        ('0744', true),
        ('0700', true),
        ('0711', true),
        ('0610', true),
        ('0601', true),
        ('0644', false),
        ('0666', false),
        ('0600', false),
      ]) {
        final file = File(p.join(scratch.path, mode, 'clang'))
          ..parent.createSync(recursive: true)
          ..writeAsStringSync('#!/bin/sh\n');
        Process.runSync('/bin/chmod', [mode, file.path]);
        String found() => onPath('clang', _platform, path: path([mode]));

        if (runnable) {
          check(because: mode, found()).equals(file.path);
        } else {
          check(because: mode, found).throws<CompilerException>();
        }
      }
    });

    test('finds none when nothing of the name can be run', () {
      make('plain', executable: false);

      check(
        () => onPath('clang', _platform, path: path(['', 'plain'])),
      ).throws<CompilerException>();
    });
  }, testOn: '!windows');
}
