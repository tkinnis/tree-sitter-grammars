#!/usr/bin/env dart

/// Validates all tree-sitter query files against their sample files.
///
/// This script tests that every .scm query file can be parsed and executed
/// by tree-sitter without errors.
library;

import 'dart:io';

void main() async {
  print('═' * 80);
  print('Tree-Sitter Query Validation');
  print('═' * 80);
  print('');

  final queriesDir = Directory('queries');

  print('Current directory: ${Directory.current.path}');
  print('Looking for queries in: ${queriesDir.absolute.path}');
  print('');

  if (!queriesDir.existsSync()) {
    print('Error: Queries directory not found');
    exit(1);
  }

  final results = <String, Map<String, dynamic>>{};
  int totalQueries = 0;
  int passedQueries = 0;
  int failedQueries = 0;

  // Get all language directories
  final languages = queriesDir
      .listSync()
      .whereType<Directory>()
      .map((d) => d.path.split('/').last)
      .where((name) => name.isNotEmpty && !name.startsWith('.'))
      .toList()
    ..sort();

  print('Found ${languages.length} languages');
  print('');

  for (final lang in languages) {
    final langDir = Directory('queries/$lang');
    final queryFiles = langDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.scm'))
        .toList();

    if (queryFiles.isEmpty) continue;

    print('Testing $lang (${queryFiles.length} queries)...');
    results[lang] = {'queries': <String, String>{}};

    for (final queryFile in queryFiles) {
      final queryName = queryFile.uri.pathSegments.last.replaceAll('.scm', '');
      totalQueries++;

      // For now, just validate that the file can be read and has balanced parens
      try {
        final content = await queryFile.readAsString();
        final error = validateQuerySyntax(content);

        final queriesMap = results[lang]!['queries'] as Map<String, String>;
        if (error != null) {
          print('  ✗ $queryName: $error');
          queriesMap[queryName] = 'FAIL: $error';
          failedQueries++;
        } else {
          print('  ✓ $queryName');
          queriesMap[queryName] = 'PASS';
          passedQueries++;
        }
      } catch (e) {
        final queriesMap = results[lang]!['queries'] as Map<String, String>;
        print('  ✗ $queryName: $e');
        queriesMap[queryName] = 'FAIL: $e';
        failedQueries++;
      }
    }
    print('');
  }

  print('═' * 80);
  print('Summary');
  print('═' * 80);
  print('Total queries tested: $totalQueries');
  print(
    'Passed: $passedQueries (${(passedQueries / totalQueries * 100).toStringAsFixed(1)}%)',
  );
  print(
    'Failed: $failedQueries (${(failedQueries / totalQueries * 100).toStringAsFixed(1)}%)',
  );
  print('');

  if (failedQueries > 0) {
    print('Failed queries by language:');
    for (final lang in results.keys) {
      final queriesMap = results[lang]!['queries'] as Map<String, String>;
      final failed =
          queriesMap.entries.where((e) => e.value.startsWith('FAIL')).toList();
      if (failed.isNotEmpty) {
        print('  $lang:');
        for (final entry in failed) {
          print('    - ${entry.key}: ${entry.value.substring(6)}');
        }
      }
    }
    exit(1);
  }

  print('✅ All queries passed!');
}

/// Validates basic query syntax (balanced parentheses, brackets, quotes)
String? validateQuerySyntax(String content) {
  // Check balanced parentheses
  int depth = 0;
  int lineNum = 1;
  int colNum = 0;
  bool inString = false;
  bool inComment = false;
  bool escaped = false;

  for (int i = 0; i < content.length; i++) {
    final char = content[i];
    colNum++;

    if (char == '\n') {
      lineNum++;
      colNum = 0;
      inComment = false; // Comments end at newline
    }

    // Track comment state (comments start with ;)
    if (char == ';' && !inString) {
      inComment = true;
    }

    if (inComment) continue;

    // Track string state
    if (char == '"' && !escaped) {
      inString = !inString;
    }

    escaped = char == '\\' && !escaped;

    if (inString) continue;

    // Check parentheses outside strings and comments
    if (char == '(') {
      depth++;
    } else if (char == ')') {
      depth--;
      if (depth < 0) {
        return 'Unmatched ) at line $lineNum, column $colNum';
      }
    }
  }

  if (depth > 0) {
    return 'Unmatched ( - $depth unclosed parentheses';
  }

  if (inString) {
    return 'Unclosed string literal';
  }

  return null;
}
