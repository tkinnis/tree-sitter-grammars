#!/usr/bin/env dart

/// Converts nvim-treesitter queries to standard tree-sitter queries
///
/// This script converts Neovim-specific predicates to standard tree-sitter predicates:
/// - `#lua-match?` -> `#match?` (with pattern conversion if needed)
/// - `#any-of?` -> Multiple query patterns (one per value)
/// - `#eq?` -> `#match?` with exact match
/// - Removes: `#set!`, `#trim!`, `#offset!`, `#set-lang-from-info-string!`
library;

import 'dart:io';

void main(List<String> args) async {
  final projectRoot = Directory.current.path;
  final patchesDir = Directory('$projectRoot/patches');

  if (!patchesDir.existsSync()) {
    print('Error: patches directory not found');
    exit(1);
  }

  print('Converting nvim-treesitter queries to standard tree-sitter...\n');

  int filesProcessed = 0;
  int filesModified = 0;

  // Process all .scm files in patches/
  await for (final entity in patchesDir.list(recursive: true)) {
    if (entity is File && entity.path.endsWith('.scm')) {
      filesProcessed++;
      final modified = await convertQueryFile(entity);
      if (modified) {
        filesModified++;
        print('✓ Converted: ${entity.path.replaceAll(projectRoot, '.')}');
      }
    }
  }

  print('\n✓ Conversion complete!');
  print('  Files processed: $filesProcessed');
  print('  Files modified: $filesModified');
  print('\nNext steps:');
  print(
    '  1. Manually merge inherited queries (cpp, javascript, typescript, tsx, objc, php)',
  );
  print(
    '  2. Run: dart run tool/build_tree_sitter_grammars.dart tool/grammars.json',
  );
  print('  3. Test the changes');
}

Future<bool> convertQueryFile(File file) async {
  final originalContent = await file.readAsString();
  var content = originalContent;
  var modified = false;

  // Step 1: Expand #any-of? patterns FIRST
  if (content.contains('#any-of?')) {
    final result = expandAnyOfPatterns(content);
    if (result != content) {
      content = result;
      modified = true;
    }
  }

  // Step 2: Convert #lua-match? to #match?
  if (content.contains('#lua-match?')) {
    content = content.replaceAll('#lua-match?', '#match?');
    modified = true;
  }

  // Step 3: Convert #eq? to #match? with exact match
  // Pattern: (#eq? @capture "value") -> (#match? @capture "^value$")
  final eqPattern = RegExp(r'\(#eq\?\s+(@\w+)\s+"([^"]+)"\)');
  if (content.contains(eqPattern)) {
    content = content.replaceAllMapped(eqPattern, (match) {
      final capture = match.group(1);
      final value = match.group(2);
      // Escape regex special characters in the value
      final escapedValue = escapeRegex(value!);
      return '(#match? $capture "^$escapedValue\$")';
    });
    modified = true;
  }

  // Step 4: Remove #set! directives (metadata, not needed for standard tree-sitter)
  final setPattern = RegExp(r'\s*\(#set!\s+[^)]+\)\s*', multiLine: true);
  if (content.contains(setPattern)) {
    content = content.replaceAll(setPattern, '\n');
    modified = true;
  }

  // Step 5: Remove #trim! directives
  final trimPattern = RegExp(r'\s*\(#trim!\s+[^)]+\)\s*', multiLine: true);
  if (content.contains(trimPattern)) {
    content = content.replaceAll(trimPattern, '\n');
    modified = true;
  }

  // Step 6: Remove #offset! directives
  final offsetPattern = RegExp(r'\s*\(#offset!\s+[^)]+\)\s*', multiLine: true);
  if (content.contains(offsetPattern)) {
    content = content.replaceAll(offsetPattern, '\n');
    modified = true;
  }

  // Step 7: Remove #set-lang-from-info-string! directives
  final setLangPattern =
      RegExp(r'\s*\(#set-lang-from-info-string!\s+[^)]+\)\s*', multiLine: true);
  if (content.contains(setLangPattern)) {
    content = content.replaceAll(setLangPattern, '\n');
    modified = true;
  }

  // Step 8: Clean up multiple consecutive blank lines
  content = content.replaceAll(RegExp(r'\n{3,}'), '\n\n');

  if (modified) {
    await file.writeAsString(content);
  }

  return modified;
}

/// Expands `#any-of?` patterns into multiple patterns with `#match?`
///
/// Example:
///   `((word) @boolean (#any-of? @boolean "true" "false"))`
/// Becomes:
///   `((word) @boolean (#match? @boolean "^true$"))`
///   `((word) @boolean (#match? @boolean "^false$"))`
String expandAnyOfPatterns(String content) {
  final lines = content.split('\n');
  final result = <String>[];
  var i = 0;

  while (i < lines.length) {
    // Extract the next complete pattern
    final patternInfo = extractQueryPattern(lines, i);

    if (patternInfo == null) {
      // Not a pattern, just add the line
      result.add(lines[i]);
      i++;
      continue;
    }

    final patternLines = patternInfo['lines'] as List<String>;
    final endIndex = patternInfo['endIndex'] as int;
    final pattern = patternLines.join('\n');

    // Check if this pattern contains #any-of?
    if (!pattern.contains('#any-of?')) {
      // No #any-of?, keep pattern as-is
      result.addAll(patternLines);
      i = endIndex + 1;
      continue;
    }

    // Parse #any-of? from the pattern
    final anyOfInfo = parseAnyOf(pattern);
    if (anyOfInfo == null) {
      // Could not parse #any-of?, keep original
      result.addAll(patternLines);
      i = endIndex + 1;
      continue;
    }

    // Generate expanded patterns
    final capture = anyOfInfo['capture'] as String;
    final values = anyOfInfo['values'] as List<String>;
    final basePattern = anyOfInfo['basePattern'] as String;

    // Create one pattern per value
    for (var j = 0; j < values.length; j++) {
      final value = values[j];
      final escapedValue = escapeRegex(value);
      final expandedPattern = basePattern.replaceAll(
        anyOfInfo['originalPredicate'] as String,
        '(#match? $capture "^$escapedValue\$")',
      );

      result.add(expandedPattern);

      // Add blank line between expanded patterns (except after last one)
      if (j < values.length - 1) {
        result.add('');
      }
    }

    // Move to next line after this pattern
    i = endIndex + 1;
  }

  return result.join('\n');
}

/// Extracts a complete query pattern starting from the given line
///
/// Returns null if the line is not the start of a pattern, otherwise returns:
/// `{ 'lines': List<String>, 'startIndex': int, 'endIndex': int }`
Map<String, dynamic>? extractQueryPattern(List<String> lines, int startIndex) {
  final line = lines[startIndex];

  // Skip comments and blank lines
  if (line.trim().isEmpty || line.trim().startsWith(';')) {
    return null;
  }

  // Check if this line starts a pattern (begins with '(' or '[')
  final trimmed = line.trimLeft();
  if (!trimmed.startsWith('(') && !trimmed.startsWith('[')) {
    return null;
  }

  final patternLines = <String>[];
  var depth = 0;

  for (var i = startIndex; i < lines.length; i++) {
    final currentLine = lines[i];
    patternLines.add(currentLine);

    // Count parentheses and brackets
    for (var j = 0; j < currentLine.length; j++) {
      final char = currentLine[j];
      if (char == '(' || char == '[') {
        depth++;
      } else if (char == ')' || char == ']') {
        depth--;
      }
    }

    // Pattern is complete when depth returns to 0
    if (depth == 0) {
      return {
        'lines': patternLines,
        'startIndex': startIndex,
        'endIndex': i,
      };
    }
  }

  return null;
}

/// Parses a `#any-of?` predicate from a pattern
///
/// Returns:
/// `{ 'capture': String, 'values': List<String>, 'basePattern': String, 'originalPredicate': String }`
Map<String, dynamic>? parseAnyOf(String pattern) {
  // Pattern: (#any-of? @capture "value1" "value2" ...)
  // Can contain comments within the predicate

  // Find the start of #any-of?
  final startMatch = RegExp(r'\(#any-of\?\s+(@[\w.]+)').firstMatch(pattern);
  if (startMatch == null) return null;

  final capture = startMatch.group(1)!;
  final startPos = startMatch.start;

  // Find the matching closing paren
  var depth = 0;
  var endPos = -1;
  for (var i = startPos; i < pattern.length; i++) {
    if (pattern[i] == '(') depth++;
    if (pattern[i] == ')') {
      depth--;
      if (depth == 0) {
        endPos = i + 1;
        break;
      }
    }
  }

  if (endPos == -1) return null;

  final originalPredicate = pattern.substring(startPos, endPos);

  // Extract all quoted values from the predicate, ignoring comments
  // Remove comment lines first
  final predicateWithoutComments = originalPredicate
      .split('\n')
      .where((line) => !line.trim().startsWith(';'))
      .join('\n');

  final valueRegex = RegExp(r'"([^"]*)"');
  final values = valueRegex
      .allMatches(predicateWithoutComments)
      .map((m) => m.group(1)!)
      .toList();

  if (values.isEmpty) return null;

  return {
    'capture': capture,
    'values': values,
    'basePattern': pattern,
    'originalPredicate': originalPredicate,
  };
}

String escapeRegex(String value) => value
    .replaceAll(r'\', r'\\')
    .replaceAll(r'.', r'\.')
    .replaceAll(r'^', r'\^')
    .replaceAll(r'$', r'\$')
    .replaceAll(r'*', r'\*')
    .replaceAll(r'+', r'\+')
    .replaceAll(r'?', r'\?')
    .replaceAll(r'[', r'\[')
    .replaceAll(r']', r'\]')
    .replaceAll(r'{', r'\{')
    .replaceAll(r'}', r'\}')
    .replaceAll(r'(', r'\(')
    .replaceAll(r')', r'\)')
    .replaceAll(r'|', r'\|');
