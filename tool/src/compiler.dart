/// The C compiler, the flags every library is built with, and the record of
/// each compiler invocation.
///
/// Every flag list is written once, here. The build passes these lists to
/// the compiler and records the same lists in `build_info.json`, so the
/// record cannot drift from what ran.
library;

import 'dart:io';

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

/// The Xcode clang and macOS SDK the build uses.
final class Compiler {
  const Compiler({
    required this.path,
    required this.version,
    required this.sdkPath,
    required this.sdkVersion,
    required this.sdkBuildVersion,
  });

  /// Absolute path of the clang binary, as `xcrun --find clang` reports it.
  final String path;

  /// The first line of `clang --version`.
  final String version;

  /// The macOS SDK passed as `-isysroot`.
  final String sdkPath;

  /// `xcrun --sdk macosx --show-sdk-version`.
  final String sdkVersion;

  /// `xcrun --sdk macosx --show-sdk-build-version`.
  final String sdkBuildVersion;

  /// Resolves clang and the SDK through `xcrun`, which honours
  /// `DEVELOPER_DIR`.
  static Future<Compiler> resolve() async {
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
}

/// The variables a compiler invocation inherits from [parent]; every other
/// variable, `CFLAGS`, `CPPFLAGS` and `LDFLAGS` among them, is left out.
///
/// clang finds the SDK through the explicit `-isysroot`, and its own
/// linker beside itself, so it needs no search path of the user's.
Map<String, String> compilerEnvironment(Map<String, String> parent) => {
  'PATH': '/usr/bin:/bin:/usr/sbin:/sbin',
  for (final name in const ['TMPDIR', 'DEVELOPER_DIR'])
    if (parent[name] case final value?) name: value,
};

/// The flags every build passes, by kind of invocation.
final class BuildFlags {
  /// Derives every flag list from [toolchain] and [compiler].
  ///
  /// `-O3` is explicit in each list, and none defines `NDEBUG`, so
  /// tree-sitter's internal assertions stay on.
  factory BuildFlags(Toolchain toolchain, Compiler compiler) {
    final target = [
      '-arch',
      toolchain.arch,
      '-mmacosx-version-min=${toolchain.deploymentTarget}',
      '-isysroot',
      compiler.sdkPath,
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

/// The flags a grammar's link passes after [BuildFlags.grammarLink]: the
/// install name of `lib<libraryName>.dylib`.
List<String> grammarLinkFlags(String libraryName) => [
  '-Wl,-install_name,@rpath/lib$libraryName.dylib',
];

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
/// `@rpath/lib<libraryName>.dylib`; paths are relative to [directory].
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
    ...grammarLinkFlags(libraryName),
    ...objects,
    '-o',
    output,
  ],
  output: output,
  environment: environment,
);
