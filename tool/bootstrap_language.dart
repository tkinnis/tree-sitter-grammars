#!/usr/bin/env dart
// Bootstrap query files for a new language from nvim-treesitter.
//
// This script imports high-quality query files from the nvim-treesitter project
// for bootstrapping new language support. It should only be used for languages
// that don't already have query files.
//
// Usage:
//   dart run tool/bootstrap_language.dart --language=<name> [options]
//
// Options:
//   --language=NAME  Language to bootstrap (required)
//   --force          Overwrite existing queries (use with caution)
//   --dry-run        Show what would be imported without copying
//   --help           Show this help

import 'dart:io';

/// Map our language names to nvim-treesitter directory names when they differ
const languageNameMap = <String, String>{
  'c-sharp': 'c_sharp',
};

/// Query types to import from nvim-treesitter
const queryTypesToImport = [
  'highlights',
  'folds',
  'injections',
  'locals',
  'indents',
];

/// Custom query files that we maintain ourselves (not from nvim-treesitter)
/// Tags files use a different format in nvim-treesitter, so we write our own
const customQueryTypes = ['tags'];

void main(List<String> args) async {
  final force = args.contains('--force');
  final dryRun = args.contains('--dry-run');
  final showHelp = args.contains('--help');
  final languageName = args
      .where((arg) => arg.startsWith('--language='))
      .map((arg) => arg.substring('--language='.length))
      .firstOrNull;

  if (showHelp || languageName == null) {
    print('''
Bootstrap query files for a new language from nvim-treesitter

This tool imports query files (.scm) from the nvim-treesitter project to
queries/<language>/. Use this when adding support for a new language.

Usage:
  dart run tool/bootstrap_language.dart --language=<name> [options]

Options:
  --language=NAME  Language to bootstrap (required)
  --force          Overwrite existing queries (use with caution)
  --dry-run        Show what would be imported without copying
  --help           Show this help

Examples:
  dart run tool/bootstrap_language.dart --language=rust
  dart run tool/bootstrap_language.dart --language=kotlin --dry-run
  dart run tool/bootstrap_language.dart --language=swift --force
''');
    exit(showHelp ? 0 : 1);
  }

  print('=== Bootstrap Language: $languageName ===\n');

  // Check if queries already exist
  final queriesDir = Directory('queries/$languageName');
  if (queriesDir.existsSync() && !force) {
    print('Error: Queries already exist for "$languageName"');
    print('  Path: ${queriesDir.path}');
    print('');
    print('This tool is for bootstrapping NEW languages only.');
    print(
      'If you want to update existing queries, use --force (with caution).',
    );
    exit(1);
  }

  if (queriesDir.existsSync() && force) {
    print('Warning: Overwriting existing queries for "$languageName"\n');
  }

  // Clone or update nvim-treesitter
  final nvimTsDir = Directory('/tmp/nvim-treesitter');
  if (!nvimTsDir.existsSync()) {
    print('Cloning nvim-treesitter repository...');
    final result = await Process.run(
      'git',
      [
        'clone',
        '--depth',
        '1',
        'https://github.com/nvim-treesitter/nvim-treesitter.git',
        nvimTsDir.path,
      ],
    );
    if (result.exitCode != 0) {
      print('Error cloning repository: ${result.stderr}');
      exit(1);
    }
    print('Cloned nvim-treesitter\n');
  } else {
    print('Updating nvim-treesitter repository...');
    final result = await Process.run(
      'git',
      ['pull'],
      workingDirectory: nvimTsDir.path,
    );
    if (result.exitCode != 0) {
      print('Warning: Could not update repository: ${result.stderr}');
    }
    print('Updated nvim-treesitter\n');
  }

  // Find source queries
  final nvimName = languageNameMap[languageName] ?? languageName;
  final nvimQueryDir = Directory('/tmp/nvim-treesitter/queries/$nvimName');

  if (!nvimQueryDir.existsSync()) {
    print('Error: Language "$languageName" not found in nvim-treesitter');
    print('  Tried: queries/$nvimName/');
    print('');
    print('Available languages can be found at:');
    print(
      '  https://github.com/nvim-treesitter/nvim-treesitter/tree/main/queries',
    );
    exit(1);
  }

  // Create target directory
  if (!dryRun) {
    await queriesDir.create(recursive: true);
  }

  // Import query files
  var importedCount = 0;
  var skippedCount = 0;

  print('Importing queries from nvim-treesitter...\n');

  for (final queryType in queryTypesToImport) {
    final sourceFile = File('${nvimQueryDir.path}/$queryType.scm');
    final targetFile = File('${queriesDir.path}/$queryType.scm');

    if (!sourceFile.existsSync()) {
      print('  $queryType.scm: Not available in nvim-treesitter');
      skippedCount++;
      continue;
    }

    if (dryRun) {
      print('  $queryType.scm: Would import');
    } else {
      await sourceFile.copy(targetFile.path);
      print('  $queryType.scm: Imported');
    }
    importedCount++;
  }

  // Create placeholder for custom query types
  for (final queryType in customQueryTypes) {
    final targetFile = File('${queriesDir.path}/$queryType.scm');

    if (targetFile.existsSync()) {
      print('  $queryType.scm: Already exists (preserved)');
      continue;
    }

    if (dryRun) {
      print('  $queryType.scm: Would create placeholder');
    } else {
      await targetFile.writeAsString('''; $queryType.scm for $languageName
;
; This file defines symbol extraction patterns for code navigation.
; See: https://tree-sitter.github.io/tree-sitter/syntax-highlighting#tags
;
; TODO: Add language-specific patterns

''');
      print('  $queryType.scm: Created placeholder');
    }
  }

  // Summary
  print('\n=== Summary ===');
  if (dryRun) {
    print('Dry run complete. Use without --dry-run to actually import.');
  } else {
    print(
      'Imported $importedCount query files ($skippedCount not available) to:',
    );
    print('  ${queriesDir.path}/');
    print('');
    print('Next steps:');
    print('  1. Review and customize the imported queries as needed');
    print('  2. Add symbol patterns to tags.scm for code navigation');
    print(
      '  3. Run: dart run tool/build_tree_sitter_grammars.dart tool/grammars.json',
    );
    print('  4. Test syntax highlighting with example files');
  }
}
