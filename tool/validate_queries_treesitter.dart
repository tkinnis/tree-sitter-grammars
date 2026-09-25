#!/usr/bin/env dart

/// Validates tree-sitter queries using the tree-sitter CLI.
///
/// This script:
/// 1. Reads the manifest.json to get all grammars and their info
/// 2. For each language, finds the sample file
/// 3. Runs `tree-sitter query` on each .scm file against the sample
/// 4. Reports which queries fail
library;

import 'dart:io';
import 'dart:convert';

void main() async {
  print('═' * 80);
  print('Tree-Sitter Query Validation (CLI-based)');
  print('═' * 80);
  print('');

  // Check if tree-sitter CLI is available
  final tsCheck = await Process.run('which', ['tree-sitter']);
  if (tsCheck.exitCode != 0) {
    print('Error: tree-sitter CLI not found');
    print('Install with: npm install -g tree-sitter-cli');
    exit(1);
  }
  print('✓ tree-sitter CLI found');
  print('');

  // Load manifest
  final manifestFile = File('output/manifest.json');
  if (!manifestFile.existsSync()) {
    print('Error: manifest.json not found');
    exit(1);
  }

  final manifest =
      jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;

  // Load grammars.json for additional info like "path" field
  final grammarsFile = File('tool/grammars.json');
  final grammarsList = grammarsFile.existsSync()
      ? jsonDecode(await grammarsFile.readAsString()) as List<dynamic>
      : <dynamic>[];

  // Build a map of language -> grammar info
  final grammarsMap = <String, Map<String, dynamic>>{};
  for (final item in grammarsList) {
    final grammarInfo = item as Map<String, dynamic>;
    final url = grammarInfo['url'] as String;
    final repoName = url.split('/').last;
    final langName = repoName.replaceFirst('tree-sitter-', '');
    grammarsMap[langName] = grammarInfo;
  }
  print('✓ Loaded manifest with ${manifest.length} grammars');
  print('');

  int totalQueries = 0;
  int passedQueries = 0;
  int failedQueries = 0;
  int skippedQueries = 0;
  final failures = <String, String>{};

  // Process each language
  for (final entry in manifest.entries) {
    final lang = entry.key;
    final info = entry.value as Map<String, dynamic>;
    final extensions = (info['extensions'] as List<dynamic>).cast<String>();

    print('Testing $lang...');

    // Find sample file
    String? sampleFile;

    // Try different language name variations (e.g., c-sharp -> csharp)
    final langVariations = [
      lang,
      lang.replaceAll('-', ''),
      lang.replaceAll('-', '_'),
    ];

    for (final langVar in langVariations) {
      for (final ext in extensions) {
        final extClean = ext.startsWith('.') ? ext.substring(1) : ext;
        final candidates = [
          'example/lib/samples/$langVar.$extClean',
          'example/lib/samples/${langVar}_medium.$extClean',
          'example/lib/samples/${langVar}_small.$extClean',
        ];

        for (final candidate in candidates) {
          if (File(candidate).existsSync()) {
            sampleFile = candidate;
            break;
          }
        }
        if (sampleFile != null) break;
      }
      if (sampleFile != null) break;
    }

    if (sampleFile == null) {
      print('  ⚠️  No sample file found');
      skippedQueries++;
      continue;
    }

    print('  Sample: $sampleFile');

    // Test each query type
    final queriesDir = Directory('queries/$lang');
    if (!queriesDir.existsSync()) {
      print('  ⚠️  No queries directory');
      continue;
    }

    final queryFiles = queriesDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.scm'))
        .toList();

    // Find the grammar directory
    String? grammarDirPath;

    // Check if there's a "path" field in grammars.json (e.g., csv)
    final grammarInfo =
        grammarsMap[lang] ?? grammarsMap[lang.replaceAll('-', '')];
    final subPath = grammarInfo?['path'] as String?;

    if (subPath != null) {
      // Grammar with subdirectory (e.g., tree-sitter-csv/csv/)
      grammarDirPath = 'grammars/tree-sitter-$lang/$subPath';
      if (!Directory(grammarDirPath).existsSync()) {
        grammarDirPath =
            'grammars/tree-sitter-${lang.replaceAll('-', '')}/$subPath';
      }
    } else {
      // Standard grammar directory
      grammarDirPath = 'grammars/tree-sitter-$lang';
      if (!Directory(grammarDirPath).existsSync()) {
        // Try alternative names (e.g., c-sharp -> csharp)
        final altNames = [
          'grammars/tree-sitter-${lang.replaceAll('-', '')}',
          'grammars/tree-sitter-${lang.replaceAll('-', '_')}',
        ];
        for (final altName in altNames) {
          if (Directory(altName).existsSync()) {
            grammarDirPath = altName;
            break;
          }
        }
      }
    }

    if (grammarDirPath == null || !Directory(grammarDirPath).existsSync()) {
      print('  ⚠️  Grammar directory not found: $grammarDirPath');
      skippedQueries++;
      continue;
    }

    final grammarDir = Directory(grammarDirPath);

    for (final queryFile in queryFiles) {
      final queryName = queryFile.uri.pathSegments.last.replaceAll('.scm', '');
      totalQueries++;

      // Calculate relative path from grammar directory to root
      // Count directory depth to determine how many ../ we need
      final depth =
          grammarDir.path.split('/').where((s) => s.isNotEmpty).length;
      final upPath = List.filled(depth, '..').join('/');

      // Run tree-sitter query from within the grammar directory
      // so it can find the grammar.js
      final result = await Process.run(
        'tree-sitter',
        ['query', '$upPath/${queryFile.path}', '$upPath/$sampleFile'],
        workingDirectory: grammarDir.path,
        runInShell: true,
      );

      if (result.exitCode == 0) {
        print('    ✓ $queryName');
        passedQueries++;
      } else {
        final error = (result.stderr as String).split('\n').first;
        print('    ✗ $queryName: $error');
        failedQueries++;
        failures['$lang/$queryName'] = error;
      }
    }

    print('');
  }

  print('═' * 80);
  print('Summary');
  print('═' * 80);
  print('Total queries tested: $totalQueries');
  String percent(int count) => (count / totalQueries * 100).toStringAsFixed(1);
  print('Passed: $passedQueries (${percent(passedQueries)}%)');
  print('Failed: $failedQueries (${percent(failedQueries)}%)');
  print('Skipped: $skippedQueries (no sample)');
  print('');

  if (failedQueries > 0) {
    print('Failed queries:');
    failures.forEach((query, error) {
      print('  • $query');
      print('    $error');
    });
    print('');
    exit(1);
  }

  print('✅ All queries passed!');
}
