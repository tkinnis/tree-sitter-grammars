/// The C compiler, the flags every library is built with, and the record of
/// each compiler invocation.
///
/// Every flag list is written once, here. The build passes these lists to
/// the compiler and records the same lists in `build_info.json`, so the
/// record cannot drift from what ran.
///
/// On macOS the compiler is the clang of the Xcode `xcrun` selects. On
/// Linux it is the first `clang` on `PATH`, targeting the platform's GNU
/// triple and linking with the system's linker against the system's C
/// library, which `build_info.json` records as macOS records its SDK. On
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
    this.hostLibcPath,
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

  /// On Linux, the build host's C library, which every library links
  /// against, as `getconf GNU_LIBC_VERSION` names it, for example
  /// `glibc 2.43`; null on macOS and Windows. It is not the glibc a library
  /// needs, which is the highest `GLIBC_` version its symbols name.
  final String? hostLibc;

  /// On Linux, the build host's `libc.so.6` clang links against, as
  /// `clang -print-file-name=libc.so.6` finds it for the platform's target.
  final String? hostLibcPath;

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

  /// Resolves clang and the C library for a build on [platform].
  ///
  /// clang is the first `clang` on `PATH`; the C library is the
  /// host's `libc.so.6` it links against for [platform]'s target, and its
  /// version what `getconf GNU_LIBC_VERSION` reports.
  static Future<Compiler> _resolveLinux(BuildPlatform platform) async {
    final path = _onPath('clang', platform);
    final environment = compilerEnvironment(Platform.environment);
    Future<String> run(String executable, List<String> arguments) async {
      final result = await Process.run(
        executable,
        arguments,
        environment: environment,
        includeParentEnvironment: false,
      );
      if (result.exitCode != 0) {
        throw CompilerException(
          '$executable ${arguments.join(' ')} failed: ${result.stderr}',
        );
      }
      return (result.stdout as String).trim();
    }

    final libcPath = await run(path, [
      '--target=${platform.linuxTarget}',
      '-print-file-name=libc.so.6',
    ]);
    if (!p.isAbsolute(libcPath)) {
      throw CompilerException(
        '$path finds no libc.so.6 for ${platform.linuxTarget}; install the '
        'C library for that target',
      );
    }
    final libc = await run('getconf', ['GNU_LIBC_VERSION']);
    if (!RegExp(r'^glibc \d+\.\d+').hasMatch(libc)) {
      throw CompilerException(
        'getconf GNU_LIBC_VERSION reports $libc; a build on Linux links '
        'against glibc',
      );
    }
    return Compiler(
      path: path,
      version: (await run(path, ['--version'])).split('\n').first.trim(),
      platform: platform,
      hostLibc: libc,
      hostLibcPath: p.normalize(libcPath),
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
    final path = _onPath('clang.exe', platform);
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

/// The absolute path of the first [executable] in a directory `PATH`
/// lists, which a build on [platform] compiles with; throws a
/// [CompilerException] when there is none.
String _onPath(String executable, BuildPlatform platform) {
  final separator = Platform.isWindows ? ';' : ':';
  for (final directory in (Platform.environment['PATH'] ?? '').split(
    separator,
  )) {
    if (directory.isEmpty) continue;
    final candidate = p.join(directory, executable);
    if (File(candidate).existsSync()) return p.normalize(candidate);
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
/// linker beside itself, so it needs no search path of the user's; on
/// Linux it finds the system's headers, C library and linker under `/usr`,
/// which is where `PATH` points. On
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
  /// Every library is linked `-shared` with its file name as its soname,
  /// as the macOS link gives each its install name, and with `-z defs`, so
  /// a symbol nothing defines fails the link, as it does on macOS and
  /// Windows, rather than the first load. The runtime takes none of the
  /// Darwin defines, which glibc does not read.
  factory BuildFlags._linux(Compiler compiler) {
    final platform = compiler.platform;
    final target = ['--target=${platform.linuxTarget}'];
    const prefixMap = '-ffile-prefix-map=$workingDirectoryPlaceholder=.';
    const link = ['-Wl,-z,defs'];
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
