#!/usr/bin/env dart

/// Compares current config.json files with the last released version.
///
/// This script extracts the release archive and compares each language's
/// config.json to identify what fields were added, removed, or changed.
///
/// Usage:
///   dart run tool/compare_configs.dart
library;

import 'dart:convert';
import 'dart:io';

void main(List<String> args) async {
  print('Comparing config.json files with last release...\n');

  // Find the release archive
  final archiveFile = File('output/grammars-macos-arm64.tar.gz');
  if (!archiveFile.existsSync()) {
    print('Error: Release archive not found at ${archiveFile.path}');
    print('Run the build first to create the archive.');
    exit(1);
  }

  // Extract to temp directory
  final tempDir = Directory('/tmp/grammars-compare');
  if (tempDir.existsSync()) {
    await tempDir.delete(recursive: true);
  }
  await tempDir.create();

  print('Extracting release archive...');
  final extractResult = await Process.run('tar', [
    '-xzf',
    archiveFile.path,
    '-C',
    tempDir.path,
  ]);
  if (extractResult.exitCode != 0) {
    print('Error extracting archive: ${extractResult.stderr}');
    exit(1);
  }

  // Compare configs
  final currentDir = Directory('output/dylibs');
  final releasedDir = Directory('${tempDir.path}/dylibs');

  if (!currentDir.existsSync()) {
    print('Error: Current output/dylibs not found');
    exit(1);
  }

  var addedFields = 0;
  var removedFields = 0;
  var changedFields = 0;
  var unchangedLanguages = 0;
  var changedLanguages = 0;

  final languages = <String>[];
  await for (final entity in currentDir.list()) {
    if (entity is Directory) {
      languages.add(entity.path.split('/').last);
    }
  }
  languages.sort();

  for (final lang in languages) {
    final currentConfig = File('${currentDir.path}/$lang/config.json');
    final releasedConfig = File('${releasedDir.path}/$lang/config.json');

    if (!currentConfig.existsSync()) continue;

    Map<String, dynamic> current;
    Map<String, dynamic> released;

    try {
      current =
          jsonDecode(await currentConfig.readAsString())
              as Map<String, dynamic>;
    } catch (e) {
      print('$lang: Error reading current config: $e');
      continue;
    }

    if (!releasedConfig.existsSync()) {
      print('$lang: NEW LANGUAGE (not in release)');
      changedLanguages++;
      continue;
    }

    try {
      released =
          jsonDecode(await releasedConfig.readAsString())
              as Map<String, dynamic>;
    } catch (e) {
      print('$lang: Error reading released config: $e');
      continue;
    }

    // Compare fields
    final allKeys = {...current.keys, ...released.keys};
    final diffs = <String>[];

    for (final key in allKeys) {
      final inCurrent = current.containsKey(key);
      final inReleased = released.containsKey(key);

      if (inCurrent && !inReleased) {
        diffs.add('  + $key: ${_formatValue(current[key])}');
        addedFields++;
      } else if (!inCurrent && inReleased) {
        diffs.add('  - $key: ${_formatValue(released[key])}');
        removedFields++;
      } else if (inCurrent && inReleased) {
        final currentVal = jsonEncode(current[key]);
        final releasedVal = jsonEncode(released[key]);
        if (currentVal != releasedVal) {
          diffs.add('  ~ $key:');
          diffs.add('      was: ${_formatValue(released[key])}');
          diffs.add('      now: ${_formatValue(current[key])}');
          changedFields++;
        }
      }
    }

    if (diffs.isEmpty) {
      unchangedLanguages++;
    } else {
      print('$lang:');
      for (final diff in diffs) {
        print(diff);
      }
      print('');
      changedLanguages++;
    }
  }

  // Cleanup
  await tempDir.delete(recursive: true);

  // Summary
  print('═' * 60);
  print('Summary');
  print('═' * 60);
  print('Languages checked: ${languages.length}');
  print('  Changed: $changedLanguages');
  print('  Unchanged: $unchangedLanguages');
  print('');
  print('Field changes:');
  print('  Added: $addedFields');
  print('  Removed: $removedFields');
  print('  Modified: $changedFields');
}

String _formatValue(dynamic value) {
  if (value is String) return '"$value"';
  if (value is List) {
    if (value.length <= 3) return jsonEncode(value);
    return '[${value.length} items]';
  }
  if (value is Map) {
    if (value.length <= 2) return jsonEncode(value);
    return '{${value.length} fields}';
  }
  return value.toString();
}
