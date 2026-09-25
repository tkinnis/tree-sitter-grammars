/// Checks each built library's Mach-O load commands and exports.
library;

import 'dart:io';

import 'toolchain.dart';

/// What one library must look like.
final class LibraryExpectation {
  const LibraryExpectation({
    required this.path,
    required this.installName,
    required this.exportedSymbols,
  });

  /// The library's path.
  final String path;

  /// The `LC_ID_DYLIB` it must carry, for example
  /// `@rpath/libtree-sitter.dylib`.
  final String installName;

  /// Symbols it must export, with their leading underscore.
  final List<String> exportedSymbols;
}

Future<String> _tool(List<String> arguments) async {
  final result = await Process.run('xcrun', arguments);
  if (result.exitCode != 0) {
    throw StateError('xcrun ${arguments.join(' ')}: ${result.stderr}');
  }
  return result.stdout as String;
}

/// Every way the library at [expectation] differs from what [toolchain]
/// requires; empty when it is right.
///
/// The library must be a thin [Toolchain.arch] binary whose install name
/// is [LibraryExpectation.installName], whose one `LC_BUILD_VERSION`
/// declares `minos` [Toolchain.deploymentTarget], which depends on nothing
/// but `libSystem`, and which exports every expected symbol.
Future<List<String>> libraryProblems(
  LibraryExpectation expectation,
  Toolchain toolchain,
) async {
  final path = expectation.path;
  final problems = <String>[];
  final archs = (await _tool(['lipo', '-archs', path])).trim();
  if (archs != toolchain.arch) problems.add('$path: architectures $archs');
  final id = (await _tool(['otool', '-D', path])).trim().split('\n').skip(1);
  if (id.join() != expectation.installName) {
    problems.add('$path: install name ${id.join()}');
  }
  final loadCommands = await _tool(['otool', '-l', path]);
  final minos = RegExp(r'^\s*minos (\S+)$', multiLine: true)
      .allMatches(loadCommands)
      .map((match) => match.group(1))
      .toList();
  if (minos.length != 1 || minos.single != toolchain.deploymentTarget) {
    problems.add('$path: minos $minos');
  }
  if (loadCommands.contains('LC_VERSION_MIN_MACOSX')) {
    problems.add('$path: carries LC_VERSION_MIN_MACOSX');
  }
  final dependencies = (await _tool(['otool', '-L', path]))
      .split('\n')
      .skip(1)
      .map((line) => line.trim().split(' ').first)
      .where((name) => name.isNotEmpty && name != expectation.installName)
      .toList();
  if (dependencies.length != 1 ||
      dependencies.single != '/usr/lib/libSystem.B.dylib') {
    problems.add('$path: depends on $dependencies');
  }
  final exported = (await _tool(['nm', '-gU', path]))
      .split('\n')
      .map((line) => line.trim().split(' ').last)
      .toSet();
  for (final symbol in expectation.exportedSymbols) {
    if (!exported.contains(symbol)) problems.add('$path: no $symbol');
  }
  return problems;
}
