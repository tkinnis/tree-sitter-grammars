#!/usr/bin/env dart
/// Migrates manifest data into queries/{lang}/config.json files.
///
/// This script reads the manifest.json and merges displayName, symbol, scope,
/// and extensions into each language's config.json file.
///
/// Usage:
///   dart run tool/migrate_manifest_to_config.dart
///   dart run tool/migrate_manifest_to_config.dart --dry-run

import 'dart:convert';
import 'dart:io';

void main(List<String> args) async {
  final dryRun = args.contains('--dry-run');

  print('Migrating manifest data to config.json files...');
  if (dryRun) {
    print('(Dry run - no files will be modified)\n');
  }
  print('');

  // Load manifest
  final manifestFile = File('output/manifest.json');
  if (!manifestFile.existsSync()) {
    print('Error: output/manifest.json not found');
    print('Run the build first to generate the manifest.');
    exit(1);
  }

  final manifest =
      jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;

  var updatedCount = 0;
  var skippedCount = 0;
  var createdCount = 0;

  for (final entry in manifest.entries) {
    final languageId = entry.key;
    final manifestData = entry.value as Map<String, dynamic>;

    final configFile = File('queries/$languageId/config.json');

    // Fields to add from manifest
    final fieldsToAdd = <String, dynamic>{};

    if (manifestData.containsKey('displayName')) {
      fieldsToAdd['displayName'] = manifestData['displayName'];
    }
    if (manifestData.containsKey('symbol')) {
      fieldsToAdd['symbol'] = manifestData['symbol'];
    }
    if (manifestData.containsKey('scope')) {
      fieldsToAdd['scope'] = manifestData['scope'];
    }
    if (manifestData.containsKey('extensions')) {
      fieldsToAdd['extensions'] = manifestData['extensions'];
    }
    if (manifestData.containsKey('filenames')) {
      fieldsToAdd['filenames'] = manifestData['filenames'];
    }
    if (manifestData.containsKey('queryOnly')) {
      fieldsToAdd['queryOnly'] = manifestData['queryOnly'];
    }

    if (configFile.existsSync()) {
      // Merge into existing config
      try {
        final existingConfig =
            jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;

        // Remove $schema as it's only for validation
        existingConfig.remove(r'$schema');

        // Merge: manifest fields first, then existing config (so existing wins for duplicates)
        final mergedConfig = <String, dynamic>{
          ...fieldsToAdd,
          ...existingConfig,
        };

        // Actually we want manifest fields to be at the top, but existing config
        // values should win for any duplicates. Let's be explicit:
        final finalConfig = <String, dynamic>{};

        // Add manifest fields first (for ordering)
        for (final key in ['displayName', 'symbol', 'scope', 'extensions', 'filenames', 'queryOnly']) {
          if (fieldsToAdd.containsKey(key)) {
            finalConfig[key] = fieldsToAdd[key];
          }
        }

        // Then add all existing config fields (these win for duplicates)
        for (final entry in existingConfig.entries) {
          finalConfig[entry.key] = entry.value;
        }

        if (dryRun) {
          print('Would update: queries/$languageId/config.json');
          print('  Adding: ${fieldsToAdd.keys.join(', ')}');
        } else {
          await configFile.writeAsString(
            const JsonEncoder.withIndent('  ').convert(finalConfig) + '\n',
          );
          print('Updated: queries/$languageId/config.json');
        }
        updatedCount++;
      } catch (e) {
        print('Error parsing queries/$languageId/config.json: $e');
        skippedCount++;
      }
    } else {
      // Create new config file
      if (fieldsToAdd.isEmpty) {
        print('Skipped: $languageId (no queries directory)');
        skippedCount++;
        continue;
      }

      final queriesDir = Directory('queries/$languageId');
      if (!queriesDir.existsSync()) {
        print('Skipped: $languageId (no queries directory)');
        skippedCount++;
        continue;
      }

      if (dryRun) {
        print('Would create: queries/$languageId/config.json');
        print('  With: ${fieldsToAdd.keys.join(', ')}');
      } else {
        await configFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(fieldsToAdd) + '\n',
        );
        print('Created: queries/$languageId/config.json');
      }
      createdCount++;
    }
  }

  print('');
  print('Summary:');
  print('  Updated: $updatedCount');
  print('  Created: $createdCount');
  print('  Skipped: $skippedCount');

  if (dryRun) {
    print('');
    print('Run without --dry-run to apply changes.');
  }
}
