/// The C compiler, the flags every library is built with, and the record of
/// each compiler invocation.
///
/// Every flag list is written once, here. The build passes these lists to
/// the compiler and records the same lists in `build_info.json`, so the
/// record cannot drift from what ran.
///
/// On macOS the compiler is the clang of the Xcode `xcrun` selects. On
/// Linux it is the first `clang` on `PATH`, targeting the platform's GNU
/// triple and linking with GNU ld (`-fuse-ld=bfd`) against the system's C
/// library; `build_info.json` records the linker's version and the
/// package and revision that installed it, and the C library's release and
/// banner, each with its path, as macOS records its SDK. On
/// Windows it is LLVM's clang driving `lld-link`, targeting
/// `*-pc-windows-msvc` against the libraries of the Visual Studio and the
/// Windows SDK it names explicitly, rather than MSVC's `cl.exe`: it takes
/// the same `-O3`, `-std=c11` and defines as the macOS build, so both
/// platforms compile the same code the same way, and it compiles the C11
/// and GNU extensions grammar scanners use, which `cl.exe` refuses or
/// reads differently. The libraries link the Visual C++ runtime statically
/// and the Universal CRT dynamically, so each depends on nothing but
/// `KERNEL32.dll` and the `api-ms-win-crt-*` DLLs every Windows 10 and
/// later carries, and they all allocate from the one heap the Universal
/// CRT keeps.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'build_platform.dart';
import 'release_check.dart' show apiFunctions, wasmOnlyFunctions;
import 'toolchain.dart';

/// Stands for an invocation's absolute working directory inside a recorded
/// flag, so the record names no path of one particular checkout.
const workingDirectoryPlaceholder = r'$PWD';

/// Thrown when a compiler invocation fails or the compiler cannot be found.
final class CompilerException implements Exception {
  const CompilerException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The clang and SDK the build uses: Xcode's clang and the macOS SDK,
/// clang and the C library on Linux, or LLVM's clang with the MSVC tools
/// and the Windows SDK.
final class Compiler {
  const Compiler({
    required this.path,
    required this.version,
    this.sdkPath,
    this.sdkVersion,
    this.sdkBuildVersion,
    this.platform = BuildPlatform.macosArm64,
    this.msvcToolsPath,
    this.msvcToolsVersion,
    this.hostLibc,
    this.hostLibcBanner,
    this.hostLibcPath,
    this.linker,
    this.linkerPackage,
    this.linkerPath,
  });

  /// Absolute path of the clang binary, as `xcrun --find clang` reports it,
  /// or on Linux and Windows the first `clang` or `clang.exe` on `PATH`.
  final String path;

  /// The first line of `clang --version`.
  final String version;

  /// The macOS SDK passed as `-isysroot`, or the root of the Windows Kits
  /// passed as `-Xmicrosoft-windows-sdk-root`; null on Linux, which builds
  /// against the system's own headers and C library.
  final String? sdkPath;

  /// `xcrun --sdk macosx --show-sdk-version`, or the Windows SDK version
  /// passed as `-Xmicrosoft-windows-sdk-version`; null on Linux.
  final String? sdkVersion;

  /// `xcrun --sdk macosx --show-sdk-build-version`; on Windows, the build
  /// number [sdkVersion] carries; null on Linux.
  final String? sdkBuildVersion;

  /// The platform every library is compiled for.
  final BuildPlatform platform;

  /// On Windows, the MSVC tools directory passed as
  /// `-Xmicrosoft-visualc-tools-root`, whose `lib/<arch>` holds the Visual
  /// C++ runtime the libraries link; null on macOS.
  final String? msvcToolsPath;

  /// On Windows, the version of the MSVC tools at [msvcToolsPath].
  final String? msvcToolsVersion;

  /// On Linux, the release of the C library at [hostLibcPath], which every
  /// library links against, as [glibcRelease] reads it from that file, for
  /// example `glibc 2.43`; null on macOS and Windows. It is not the glibc a
  /// library needs, which is the highest `GLIBC_` version its symbols name.
  final String? hostLibc;

  /// On Linux, the banner of the C library at [hostLibcPath], as
  /// [glibcBanner] reads it, which names the distribution's build of it
  /// with its revision, for example `GNU C Library (Ubuntu GLIBC
  /// 2.43-2ubuntu2.4) stable release version 2.43`; null on macOS and
  /// Windows. The startup files and static parts of glibc every library
  /// links come from that same build, which [hostLibc] alone does not name.
  final String? hostLibcBanner;

  /// On Linux, the build host's `libc.so.6` clang links against, as
  /// `clang -print-file-name=libc.so.6` finds it for the platform's target.
  final String? hostLibcPath;

  /// On Linux, the first line of `--version` of the linker at
  /// [linkerPath], for example `GNU ld (GNU Binutils for Ubuntu) 2.46`;
  /// null on macOS and Windows. The linker writes every library's bytes as
  /// much as clang does, so two builds with the same clang and glibc but
  /// another binutils record that they differ.
  final String? linker;

  /// On Linux, the package that installed the linker at [linkerPath] and
  /// its version with the distribution's revision, for example
  /// `binutils-aarch64-linux-gnu 2.46-3ubuntu2`, which [linker] leaves
  /// out; null on macOS and Windows.
  final String? linkerPackage;

  /// On Linux, the GNU ld every link runs, as
  /// `clang -print-prog-name=ld.bfd` finds it for the platform's target.
  final String? linkerPath;

  /// Resolves the compiler a build on [platform], by default the platform
  /// this process runs on, compiles with: on macOS through `xcrun`, which
  /// honours `DEVELOPER_DIR`, on Linux as [_resolveLinux] does, and on
  /// Windows as [_resolveWindows] does.
  static Future<Compiler> resolve([BuildPlatform? platform]) async {
    platform ??= BuildPlatform.host;
    if (platform.isWindows) return _resolveWindows(platform);
    if (platform.isLinux) return _resolveLinux(platform);
    Future<String> xcrun(List<String> arguments) async {
      final result = await Process.run('xcrun', arguments);
      if (result.exitCode != 0) {
        throw CompilerException(
          'xcrun ${arguments.join(' ')} failed: ${result.stderr}',
        );
      }
      return (result.stdout as String).trim();
    }

    final path = await xcrun(['--find', 'clang']);
    final version = await Process.run(
      path,
      ['--version'],
      environment: compilerEnvironment(Platform.environment),
      includeParentEnvironment: false,
    );
    if (version.exitCode != 0) {
      throw CompilerException('$path --version failed: ${version.stderr}');
    }
    return Compiler(
      path: path,
      version: (version.stdout as String).split('\n').first.trim(),
      sdkPath: await xcrun(['--sdk', 'macosx', '--show-sdk-path']),
      sdkVersion: await xcrun(['--sdk', 'macosx', '--show-sdk-version']),
      sdkBuildVersion: await xcrun([
        '--sdk',
        'macosx',
        '--show-sdk-build-version',
      ]),
    );
  }

  /// Resolves clang, the linker and the C library for a build on
  /// [platform], as [resolveLinuxCompiler] does with the first `clang` on
  /// `PATH`, every tool run with the [compilerEnvironment] each compiler
  /// invocation sees.
  static Future<Compiler> _resolveLinux(BuildPlatform platform) async {
    final environment = compilerEnvironment(Platform.environment);
    return resolveLinuxCompiler(
      platform,
      clang: onPath('clang', platform),
      run: (executable, arguments) async {
        final ProcessResult result;
        try {
          result = await Process.run(
            executable,
            arguments,
            environment: environment,
            includeParentEnvironment: false,
          );
        } on ProcessException catch (e) {
          // A tool that is not installed, such as dpkg where there is rpm.
          throw CompilerException('$executable cannot be run: ${e.message}');
        }
        if (result.exitCode != 0) {
          throw CompilerException(
            '$executable ${arguments.join(' ')} failed: ${result.stderr}',
          );
        }
        return (result.stdout as String).trim();
      },
    );
  }

  /// Resolves LLVM's clang, the MSVC tools and the Windows SDK for a build
  /// on [platform].
  ///
  /// clang is the first `clang.exe` on `PATH`. The MSVC tools are the
  /// default version of the newest Visual Studio `vswhere` finds with the
  /// tools for [platform]'s architecture, and the SDK the newest version
  /// under the Windows Kits root the registry names that holds the
  /// Universal CRT and the import libraries for that architecture. Each is
  /// passed to clang by path, so no `INCLUDE`, `LIB` or developer prompt
  /// of the user's decides what the libraries are compiled and linked
  /// against.
  static Future<Compiler> _resolveWindows(BuildPlatform platform) async {
    final path = onPath('clang.exe', platform);
    final version = await Process.run(
      path,
      ['--version'],
      environment: compilerEnvironment(Platform.environment),
      includeParentEnvironment: false,
    );
    if (version.exitCode != 0) {
      throw CompilerException('$path --version failed: ${version.stderr}');
    }
    final (:msvcPath, :msvcVersion) = await _msvcTools(platform);
    final (:sdkRoot, :sdkVersion) = await _windowsSdk(platform);
    return Compiler(
      path: path,
      version: (version.stdout as String).split('\n').first.trim(),
      sdkPath: sdkRoot,
      sdkVersion: sdkVersion,
      sdkBuildVersion: sdkVersion.split('.')[2],
      platform: platform,
      msvcToolsPath: msvcPath,
      msvcToolsVersion: msvcVersion,
    );
  }
}

/// Runs [executable] with [arguments] in the environment a compiler
/// invocation sees and returns its standard output, trimmed; throws a
/// [CompilerException] when it fails.
typedef ToolRunner =
    Future<String> Function(String executable, List<String> arguments);

/// The [Compiler] of a build on the Linux [platform] that compiles with
/// the clang at [clang], asking it through [run] what it links with.
///
/// clang is the user's: the first on `PATH`, so that an LLVM of their
/// choosing can compile. What clang runs and links against it finds
/// beside itself or on the `PATH` of [compilerEnvironment], not the
/// user's, so [run] runs it in that environment, as every compiler
/// invocation is, and its answers are what `build_info.json` records:
///
/// - the linker, GNU ld, which every link selects with `-fuse-ld=bfd` and
///   clang finds as `ld.bfd` for [platform]'s target, with the first line
///   of its `--version`, since two linkers write the same objects to
///   different bytes;
/// - the package that installed that linker, with its version and the
///   distribution's revision, which `--version` leaves out, as dpkg or,
///   where there is none, rpm names it;
/// - the C library, the `libc.so.6` clang finds for that target, with the
///   release [glibcRelease] reads from that same file and the whole
///   banner [glibcBanner] reads, which names the distribution's build, so
///   what is recorded is the library linked against, not whatever glibc
///   this process runs on.
///
/// Throws a [CompilerException] when clang finds either by no absolute
/// path, which it answers when it finds none, when the C library names no
/// glibc release, when the linker is not GNU ld, or when no package
/// database names the one package that installed it.
Future<Compiler> resolveLinuxCompiler(
  BuildPlatform platform, {
  required String clang,
  required ToolRunner run,
}) async {
  final target = '--target=${platform.linuxTarget}';
  final libcPath = await run(clang, [target, '-print-file-name=libc.so.6']);
  if (!p.isAbsolute(libcPath) || !File(libcPath).existsSync()) {
    throw CompilerException(
      '$clang finds no libc.so.6 for ${platform.linuxTarget}; install the '
      'C library for that target',
    );
  }
  final libcBytes = File(libcPath).readAsBytesSync();
  final libc = glibcRelease(libcBytes);
  final banner = glibcBanner(libcBytes);
  if (libc == null || banner == null) {
    throw CompilerException(
      '$libcPath names no glibc release; a build on Linux links against '
      'glibc',
    );
  }
  final linkerPath = await run(clang, [target, '-print-prog-name=ld.bfd']);
  if (!p.isAbsolute(linkerPath)) {
    throw CompilerException(
      '$clang finds no ld.bfd for ${platform.linuxTarget}; install GNU '
      'binutils for that target',
    );
  }
  final linker = (await run(linkerPath, ['--version'])).split('\n').first;
  if (!linker.startsWith('GNU ld ')) {
    throw CompilerException(
      '$linkerPath --version reports $linker; a build on Linux links with '
      'GNU ld',
    );
  }
  final linkerPackage = await _packageOf(linkerPath, run);
  if (linkerPackage == null) {
    throw CompilerException(
      'no package database names the one package that installed '
      '$linkerPath; a build on Linux records the binutils package and '
      'revision it links with',
    );
  }
  return Compiler(
    path: clang,
    version: (await run(clang, ['--version'])).split('\n').first.trim(),
    platform: platform,
    hostLibc: libc,
    hostLibcBanner: banner,
    hostLibcPath: p.normalize(libcPath),
    linker: linker.trim(),
    linkerPackage: linkerPackage,
    linkerPath: p.normalize(linkerPath),
  );
}

/// The package that installed [path] and its full version, its name and
/// version apart by a space, as dpkg names it or, where dpkg cannot be
/// asked, rpm; null when neither names exactly one package.
Future<String?> _packageOf(String path, ToolRunner run) async {
  try {
    final owners = [
      for (final line in (await run('/usr/bin/dpkg-query', [
        '-S',
        path,
      ])).split('\n'))
        // A diversion of the path is listed as well, and is no owner.
        if (!line.startsWith('diversion by ') && line.endsWith(': $path'))
          line.substring(0, line.length - ': $path'.length),
    ];
    if (owners.length != 1 || owners.single.contains(', ')) return null;
    final package = await run('/usr/bin/dpkg-query', [
      '-W',
      r'--showformat=${Package} ${Version}',
      owners.single,
    ]);
    return package.contains(' ') ? package : null;
  } on CompilerException {
    // No dpkg, or dpkg knows nothing of the path: ask rpm.
  }
  try {
    final package = await run('/usr/bin/rpm', [
      '-qf',
      '--queryformat',
      '%{NAME} %{EVR}',
      path,
    ]);
    return package.contains(' ') && !package.contains('\n') ? package : null;
  } on CompilerException {
    return null;
  }
}

/// The release of the GNU C library whose `libc.so.6` holds [bytes], as
/// its banner (`GNU C Library (...) stable release version 2.43.`) names
/// it, written as `getconf GNU_LIBC_VERSION` writes it, `glibc 2.43`; null
/// when the file holds no such banner.
String? glibcRelease(List<int> bytes) {
  final banner = glibcBanner(bytes);
  if (banner == null) return null;
  return 'glibc ${banner.substring(banner.lastIndexOf(' ') + 1)}';
}

/// The banner of the GNU C library whose `libc.so.6` holds [bytes], with
/// no final full stop, for example `GNU C Library (Ubuntu GLIBC
/// 2.43-2ubuntu2.4) stable release version 2.43`; null when the file holds
/// no banner that names a release.
String? glibcBanner(List<int> bytes) => RegExp(
  r'GNU C Library [^\n\x00]*? release version \d+\.\d+(?:\.\d+)?',
).firstMatch(latin1.decode(bytes))?.group(0);

/// The absolute path of the first [executable] in a directory [path], by
/// default `PATH`, lists, which a build on [platform] compiles with;
/// throws a [CompilerException] when there is none.
///
/// A file of that name that cannot be run, such as one with no execute
/// permission off Windows, is passed over, as a shell passes it over.
String onPath(String executable, BuildPlatform platform, {String? path}) {
  final separator = Platform.isWindows ? ';' : ':';
  for (final directory in (path ?? Platform.environment['PATH'] ?? '').split(
    separator,
  )) {
    if (directory.isEmpty) continue;
    final candidate = p.join(directory, executable);
    final stat = FileStat.statSync(candidate);
    if (stat.type != FileSystemEntityType.file) continue;
    // A file with no execute bit cannot be run. Windows keeps no such
    // bits, and runs a file by its name.
    if (!Platform.isWindows && stat.mode & 0x49 /* 0111 */ == 0) continue;
    return p.normalize(candidate);
  }
  throw CompilerException(
    'no $executable on PATH; a build on ${platform.osName} compiles with '
    "LLVM's clang",
  );
}

/// The default MSVC tools of the newest Visual Studio that has them for
/// [platform]'s architecture, as `vswhere` finds it.
Future<({String msvcPath, String msvcVersion})> _msvcTools(
  BuildPlatform platform,
) async {
  final vswhere = p.join(
    Platform.environment['ProgramFiles(x86)'] ?? r'C:\Program Files (x86)',
    'Microsoft Visual Studio',
    'Installer',
    'vswhere.exe',
  );
  final component = switch (platform) {
    BuildPlatform.windowsArm64 =>
      'Microsoft.VisualStudio.Component.VC.Tools.ARM64',
    _ => 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64',
  };
  final found = await Process.run(vswhere, [
    '-latest',
    '-products',
    '*',
    '-requires',
    component,
    '-property',
    'installationPath',
  ]);
  final installation = '${found.stdout}'.trim().split('\n').first.trim();
  if (found.exitCode != 0 || installation.isEmpty) {
    throw CompilerException(
      'vswhere found no Visual Studio with $component; install the MSVC '
      '${platform.windowsLibArch} build tools',
    );
  }
  final version = File(
    p.join(
      installation,
      'VC',
      'Auxiliary',
      'Build',
      'Microsoft.VCToolsVersion.default.txt',
    ),
  ).readAsStringSync().trim();
  final tools = p.join(installation, 'VC', 'Tools', 'MSVC', version);
  final runtime = p.join(tools, 'lib', platform.windowsLibArch, 'libcmt.lib');
  if (!File(runtime).existsSync()) {
    throw CompilerException('the MSVC tools $version have no $runtime');
  }
  return (msvcPath: tools, msvcVersion: version);
}

/// The newest Windows SDK under the Windows Kits root the registry names
/// that holds the Universal CRT and the import libraries for [platform].
Future<({String sdkRoot, String sdkVersion})> _windowsSdk(
  BuildPlatform platform,
) async {
  String? root;
  for (final key in const [
    r'HKLM\SOFTWARE\Microsoft\Windows Kits\Installed Roots',
    r'HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows Kits\Installed Roots',
  ]) {
    final query = await Process.run('reg', ['query', key, '/v', 'KitsRoot10']);
    final match = RegExp(
      r'KitsRoot10\s+REG_SZ\s+(.+)$',
      multiLine: true,
    ).firstMatch('${query.stdout}');
    if (query.exitCode == 0 && match != null) {
      root = p.normalize(match.group(1)!.trim());
      break;
    }
  }
  if (root == null) {
    throw const CompilerException(
      'the registry names no Windows Kits root; install the Windows SDK',
    );
  }
  final arch = platform.windowsLibArch;
  final versions = [
    for (final entity in Directory(p.join(root, 'Lib')).listSync())
      if (entity is Directory &&
          RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(p.basename(entity.path)) &&
          File(p.join(entity.path, 'ucrt', arch, 'ucrt.lib')).existsSync() &&
          File(p.join(entity.path, 'um', arch, 'kernel32.lib')).existsSync())
        p.basename(entity.path),
  ];
  if (versions.isEmpty) {
    throw CompilerException(
      '$root holds no Windows SDK with the $arch Universal CRT',
    );
  }
  List<int> parts(String version) => [
    for (final part in version.split('.')) int.parse(part),
  ];
  versions.sort((a, b) {
    final (x, y) = (parts(a), parts(b));
    for (var i = 0; i < 4; i++) {
      if (x[i] != y[i]) return x[i] - y[i];
    }
    return 0;
  });
  return (sdkRoot: root, sdkVersion: versions.last);
}

/// The variables a compiler invocation may see, by [BuildPlatform.os].
///
/// On macOS `DEVELOPER_DIR` selects the Xcode whose clang runs. On Windows
/// a process needs `SystemRoot` to start at all, and clang writes the
/// objects of a compile it links in the same invocation to `TEMP` or
/// `TMP`, as it does to `TMPDIR` on macOS and Linux.
const _compilerVariables = {
  'macos': {'PATH', 'TMPDIR', 'DEVELOPER_DIR'},
  'linux': {'PATH', 'TMPDIR'},
  'windows': {'PATH', 'SystemRoot', 'TEMP', 'TMP'},
};

/// The variables a compiler invocation may see on [platform].
Set<String> allowedCompilerVariablesOf(BuildPlatform platform) =>
    _compilerVariables[platform.os]!;

/// The variables a compiler invocation inherits from [parent]; every other
/// variable, `CFLAGS`, `CPPFLAGS` and `LDFLAGS` among them, is left out.
///
/// clang finds the SDK through the explicit `-isysroot`, and its own
/// linker beside itself, so it needs no search path of the user's. On
/// Linux it finds the system's headers and C library under `/usr`, and
/// GNU ld beside itself or on this `PATH`, not the user's, so
/// [resolveLinuxCompiler] asks it for both with this environment and
/// `build_info.json` records what it answered. On
/// Windows, where clang finds the MSVC tools and the Windows SDK through
/// the paths its flags name, and `lld-link` beside itself, `PATH` holds
/// only the system's own directories, and neither `INCLUDE` nor `LIB`
/// reaches it.
Map<String, String> compilerEnvironment(Map<String, String> parent) {
  if (Platform.isWindows) {
    final systemRoot = parent['SystemRoot'] ?? r'C:\Windows';
    return {
      'PATH': '$systemRoot\\System32;$systemRoot',
      'SystemRoot': systemRoot,
      for (final name in const ['TEMP', 'TMP'])
        if (parent[name] case final value?) name: value,
    };
  }
  return {
    'PATH': '/usr/bin:/bin:/usr/sbin:/sbin',
    for (final name in _compilerVariables[Platform.operatingSystem] ?? const {})
      if (name != 'PATH')
        if (parent[name] case final value?) name: value,
  };
}

/// The module-definition file that makes the Windows runtime export every
/// function [apiHeader], the text of its `api.h`, declares, apart from
/// [wasmOnlyFunctions], and every allocator variable [allocHeader], the
/// text of its `lib/src/alloc.h`, marks `TS_PUBLIC`, under the DLL name
/// [libraryName].
///
/// tree-sitter marks none of its API for export on Windows (its
/// `TS_PUBLIC` is empty there), so without this the DLL would export
/// nothing; the export list follows the headers at the pinned runtime, as
/// the symbol visibility of the macOS build does. The allocator variables
/// are exported as data, as the macOS runtime exports them, so a caller
/// frees what the runtime allocated for it with the runtime's own
/// `ts_current_free`.
String runtimeModuleDefinition(
  String apiHeader,
  String libraryName, {
  String allocHeader = '',
}) => [
  'LIBRARY $libraryName',
  'EXPORTS',
  for (final function in apiFunctions(apiHeader))
    if (!wasmOnlyFunctions.contains(function)) '  $function',
  for (final variable in allocatorVariables(allocHeader)) '  $variable DATA',
  '',
].join('\n');

/// Every symbol the Windows runtime compiled from the sources at
/// [runtimeDirectory] must export: the functions and allocator variables
/// [runtimeModuleDefinition] lists from its `api.h` and `alloc.h`.
List<String> runtimeExports(String runtimeDirectory) => [
  for (final function in apiFunctions(
    File(
      p.join(runtimeDirectory, 'lib', 'include', 'tree_sitter', 'api.h'),
    ).readAsStringSync(),
  ))
    if (!wasmOnlyFunctions.contains(function)) function,
  ...allocatorVariables(
    File(p.join(runtimeDirectory, 'lib', 'src', 'alloc.h')).readAsStringSync(),
  ),
];

/// The allocator variables `lib/src/alloc.h`, whose text is [allocHeader],
/// declares `TS_PUBLIC`: the function pointers through which the runtime
/// allocates, `ts_current_malloc` to `ts_current_free`.
List<String> allocatorVariables(String allocHeader) => [
  for (final match in RegExp(
    r'TS_PUBLIC\s+extern\s[^;]*\(\s*\*\s*(ts_\w+)\s*\)',
  ).allMatches(allocHeader))
    match.group(1)!,
];

/// Where the Windows runtime's module-definition file is written, relative
/// to the runtime's extracted sources, in which its link runs.
const runtimeModuleDefinitionPath = '../../tree-sitter.def';

/// The flags every build passes, by kind of invocation.
final class BuildFlags {
  /// Derives every flag list from [toolchain] and [compiler].
  ///
  /// `-O3` is explicit in each list, and none defines `NDEBUG`, so
  /// tree-sitter's internal assertions stay on.
  factory BuildFlags(Toolchain toolchain, Compiler compiler) {
    if (compiler.platform.isWindows) {
      return BuildFlags._windows(toolchain, compiler);
    }
    if (compiler.platform.isLinux) return BuildFlags._linux(compiler);
    final target = [
      '-arch',
      toolchain.arch,
      '-mmacosx-version-min=${toolchain.deploymentTarget}',
      '-isysroot',
      compiler.sdkPath!,
    ];
    const prefixMap = '-ffile-prefix-map=$workingDirectoryPlaceholder=.';
    const linkerHeaderPad = '-Wl,-headerpad_max_install_names';
    final version = toolchain.runtimeVersion;
    return BuildFlags._(
      runtime: [
        '-O3',
        '-std=c11',
        '-fPIC',
        '-fvisibility=hidden',
        '-D_POSIX_C_SOURCE=200112L',
        '-D_DEFAULT_SOURCE',
        '-D_BSD_SOURCE',
        '-D_DARWIN_C_SOURCE',
        '-Ilib/src',
        '-Ilib/src/wasm',
        '-Ilib/include',
        '-dynamiclib',
        ...target,
        prefixMap,
        '-Wl,-install_name,@rpath/libtree-sitter.dylib',
        linkerHeaderPad,
        '-Wl,-current_version,$version',
        '-Wl,-compatibility_version,$version',
      ],
      grammarCompile: ['-c', '-O3', '-std=c11', '-fPIC', ...target, prefixMap],
      grammarLink: ['-shared', ...target, linkerHeaderPad],
    );
  }

  /// The flags of a build for Windows: those of macOS where Windows has
  /// them (`-O3` and no `NDEBUG`, C11 and the runtime's defines, the
  /// prefix map), with the target's triple and the MSVC tools and SDK in
  /// place of `-arch` and `-isysroot`.
  ///
  /// Every link is by `lld-link`, with `/brepro` so that the same objects
  /// link to the same bytes, `/noimplib` so that no import library lands
  /// beside a DLL in the archive, and the Universal CRT taken dynamically in
  /// place of the static one `libcmt` names. The runtime's link exports
  /// what [runtimeModuleDefinition] lists and carries the runtime's version
  /// as its image version, as its macOS link carries `-current_version`.
  factory BuildFlags._windows(Toolchain toolchain, Compiler compiler) {
    final target = [
      '--target=${compiler.platform.windowsTarget}',
      '-fms-runtime-lib=static',
      '-Xmicrosoft-visualc-tools-root',
      compiler.msvcToolsPath!,
      '-Xmicrosoft-windows-sdk-root',
      compiler.sdkPath!,
      '-Xmicrosoft-windows-sdk-version',
      compiler.sdkVersion!,
    ];
    const prefixMap = '-ffile-prefix-map=$workingDirectoryPlaceholder=.';
    const link = [
      '-fuse-ld=lld',
      '-Wl,/nodefaultlib:libucrt.lib',
      '-Wl,/defaultlib:ucrt.lib',
      '-Wl,/brepro',
      '-Wl,/noimplib',
    ];
    final [major, minor, _] = toolchain.runtimeVersion.split('.');
    return BuildFlags._(
      runtime: [
        '-O3',
        '-std=c11',
        '-D_POSIX_C_SOURCE=200112L',
        '-D_DEFAULT_SOURCE',
        '-D_BSD_SOURCE',
        '-D_DARWIN_C_SOURCE',
        '-Ilib/src',
        '-Ilib/src/wasm',
        '-Ilib/include',
        '-shared',
        ...target,
        prefixMap,
        ...link,
        '-Wl,/def:$runtimeModuleDefinitionPath',
        '-Wl,/version:$major.$minor',
      ],
      grammarCompile: ['-c', '-O3', '-std=c11', ...target, prefixMap],
      grammarLink: ['-shared', ...target, ...link],
    );
  }

  /// The flags of a build for Linux: those of macOS (`-O3` and no
  /// `NDEBUG`, C11, `-fPIC`, the runtime's hidden visibility and its
  /// POSIX and default-source defines, the prefix map) with the
  /// platform's target triple in place of `-arch` and no SDK, since clang
  /// compiles against the system's headers and C library.
  ///
  /// Every library is linked `-shared` by GNU ld, which `-fuse-ld=bfd`
  /// names rather than leaving the choice to how clang was configured, so
  /// the linker is the one [Compiler.linker] records; with its file name as
  /// its soname, as the macOS link gives each its install name; and with
  /// `-z defs`, so a symbol nothing defines fails the link, as it does on
  /// macOS and Windows, rather than the first load. The runtime takes none
  /// of the Darwin defines, which glibc does not read.
  factory BuildFlags._linux(Compiler compiler) {
    final platform = compiler.platform;
    final target = ['--target=${platform.linuxTarget}'];
    const prefixMap = '-ffile-prefix-map=$workingDirectoryPlaceholder=.';
    const link = ['-fuse-ld=bfd', '-Wl,-z,defs'];
    return BuildFlags._(
      runtime: [
        '-O3',
        '-std=c11',
        '-fPIC',
        '-fvisibility=hidden',
        '-D_POSIX_C_SOURCE=200112L',
        '-D_DEFAULT_SOURCE',
        '-D_BSD_SOURCE',
        '-Ilib/src',
        '-Ilib/src/wasm',
        '-Ilib/include',
        '-shared',
        ...target,
        prefixMap,
        ...link,
        ...libraryNameFlags(platform.runtimeFileName, platform),
      ],
      grammarCompile: ['-c', '-O3', '-std=c11', '-fPIC', ...target, prefixMap],
      grammarLink: ['-shared', ...target, ...link],
    );
  }

  const BuildFlags._({
    required this.runtime,
    required this.grammarCompile,
    required this.grammarLink,
  });

  /// The runtime's one invocation, before its source and output.
  final List<String> runtime;

  /// Each grammar source file's compile, before its
  /// [grammarSourceFlags], source and object.
  final List<String> grammarCompile;

  /// Each grammar's link, before its [grammarLinkFlags], objects and
  /// output.
  final List<String> grammarLink;
}

/// The flags one grammar source's compile passes after
/// [BuildFlags.grammarCompile]: the directory its headers come from.
List<String> grammarSourceFlags(String includeDirectory) => [
  '-I',
  includeDirectory,
];

/// The flags a grammar's link passes after [BuildFlags.grammarLink]: those
/// [libraryNameFlags] gives its library, `lib<libraryName>.dylib` on
/// macOS and as [platform] names it elsewhere.
List<String> grammarLinkFlags(
  String libraryName, {
  BuildPlatform platform = BuildPlatform.macosArm64,
}) => libraryNameFlags(platform.libraryFileName(libraryName), platform);

/// The flags that give the library [fileName] of [platform] the name it is
/// loaded by: on macOS its install name, `@rpath/<fileName>`, and on
/// Linux its soname, `<fileName>`.
///
/// A Windows DLL has no install name: the name its export table carries is
/// its file name, which the link's output gives it, so on Windows a link
/// passes no flags for it.
List<String> libraryNameFlags(String fileName, BuildPlatform platform) =>
    switch (platform) {
      BuildPlatform.macosArm64 => ['-Wl,-install_name,@rpath/$fileName'],
      BuildPlatform.linuxArm64 => ['-Wl,-soname,$fileName'],
      BuildPlatform.windowsArm64 || BuildPlatform.windowsX64 => const [],
    };

/// [flags] with [workingDirectoryPlaceholder] replaced by the absolute
/// [workingDirectory] an invocation runs in.
List<String> expandFlags(List<String> flags, String workingDirectory) => [
  for (final flag in flags)
    flag.replaceAll(workingDirectoryPlaceholder, workingDirectory),
];

/// One compiler invocation exactly as it ran: the entries of
/// `build/compile_commands.json`.
final class CompileCommand {
  const CompileCommand({
    required this.directory,
    required this.arguments,
    required this.output,
    required this.environment,
  });

  /// Reads one entry of `build/compile_commands.json`.
  factory CompileCommand.fromJson(Map<String, Object?> json) => CompileCommand(
    directory: json['directory']! as String,
    arguments: (json['arguments']! as List).cast<String>(),
    output: json['output']! as String,
    environment: (json['environment']! as Map).cast<String, String>(),
  );

  /// The absolute working directory.
  final String directory;

  /// The full argument vector, the compiler's path first.
  final List<String> arguments;

  /// The file the invocation writes, relative to [directory].
  final String output;

  /// The complete environment the compiler ran with.
  final Map<String, String> environment;

  Map<String, Object?> toJson() => {
    'directory': directory,
    'arguments': arguments,
    'output': output,
    'environment': environment,
  };
}

/// Runs [command], throwing a [CompilerException] with the compiler's
/// output when it exits non-zero.
Future<void> runCompileCommand(CompileCommand command) async {
  final [executable, ...arguments] = command.arguments;
  final result = await Process.run(
    executable,
    arguments,
    workingDirectory: command.directory,
    environment: command.environment,
    includeParentEnvironment: false,
  );
  if (result.exitCode != 0) {
    throw CompilerException(
      '${command.output}: clang exited '
      '${result.exitCode}\n${result.stdout}${result.stderr}',
    );
  }
}

/// The runtime's one invocation: `lib/src/lib.c` in the extracted runtime at
/// [directory], written to [output] relative to it.
CompileCommand runtimeCommand({
  required Compiler compiler,
  required BuildFlags flags,
  required String directory,
  required String output,
  required Map<String, String> environment,
}) => CompileCommand(
  directory: directory,
  arguments: [
    compiler.path,
    ...expandFlags(flags.runtime, directory),
    'lib/src/lib.c',
    '-o',
    output,
  ],
  output: output,
  environment: environment,
);

/// Compiles one grammar [source] against the headers in [includeDirectory]
/// into [object]; paths are relative to [directory].
CompileCommand grammarCompileCommand({
  required Compiler compiler,
  required BuildFlags flags,
  required String directory,
  required String includeDirectory,
  required String source,
  required String object,
  required Map<String, String> environment,
}) => CompileCommand(
  directory: directory,
  arguments: [
    compiler.path,
    ...expandFlags(flags.grammarCompile, directory),
    ...grammarSourceFlags(includeDirectory),
    source,
    '-o',
    object,
  ],
  output: object,
  environment: environment,
);

/// Links one grammar's [objects] into [output], whose install name is
/// `@rpath/lib<libraryName>.dylib` on macOS and whose soname is
/// `lib<libraryName>.so` on Linux; paths are relative to [directory].
CompileCommand grammarLinkCommand({
  required Compiler compiler,
  required BuildFlags flags,
  required String directory,
  required String libraryName,
  required List<String> objects,
  required String output,
  required Map<String, String> environment,
}) => CompileCommand(
  directory: directory,
  arguments: [
    compiler.path,
    ...expandFlags(flags.grammarLink, directory),
    ...grammarLinkFlags(libraryName, platform: compiler.platform),
    ...objects,
    '-o',
    output,
  ],
  output: output,
  environment: environment,
);
