/// Checks a built `manifest.json` against the fields
/// `tool/manifest_schema.json` describes.
///
/// Usage: `dart run tool/validate_manifest.dart output/manifest.json`
///
/// Exits 1 on any error. Every compiled grammar (an entry with `dylib_dir`)
/// must name its `source`, including the 40-hex commit it was built from
/// and a language ABI the runtime loads: one from the
/// `minCompatibleLanguageVersion` to the `languageVersion` that the
/// `build_info.json` beside the manifest records of the runtime.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'src/manifest.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    print('Usage: dart tool/validate_manifest.dart <manifest_path>');
    print('Example: dart tool/validate_manifest.dart output/manifest.json');
    exit(1);
  }

  final manifestPath = args[0];
  final manifestFile = File(manifestPath);

  if (!manifestFile.existsSync()) {
    print('Error: Manifest file not found: $manifestPath');
    exit(1);
  }

  print('Validating $manifestPath...');
  print('');

  try {
    final content = manifestFile.readAsStringSync();
    final manifest = jsonDecode(content) as Map<String, dynamic>;
    final languageVersions = _languageVersions(manifestPath);
    if (languageVersions == null) {
      print(
        '✗ no build_info.json beside $manifestPath records the runtime\'s '
        'treeSitter.languageVersion and minCompatibleLanguageVersion',
      );
      exit(1);
    }

    var errorCount = 0;
    var warningCount = 0;

    for (final entry in manifest.entries) {
      final languageId = entry.key;
      final data = entry.value;

      if (data is! Map<String, dynamic>) {
        print('✗ $languageId: Must be an object');
        errorCount++;
        continue;
      }

      // 'symbol' is required only of tree-sitter languages, which have a
      // dylib_dir.
      final isTreeSitterLanguage = data.containsKey('dylib_dir');
      final requiredFields = isTreeSitterLanguage
          ? ['displayName', 'symbol', 'scope']
          : ['displayName', 'scope'];

      for (final field in requiredFields) {
        if (!data.containsKey(field)) {
          print('✗ $languageId: Missing required field "$field"');
          errorCount++;
        }
      }

      // Warn if extensions is missing (it's optional for injection grammars)
      if (!data.containsKey('extensions')) {
        print(
          '⚠ $languageId: No extensions defined (may be an injection grammar)',
        );
        warningCount++;
      }

      // Validate displayName
      if (data.containsKey('displayName')) {
        final displayName = data['displayName'];
        if (displayName is! String || displayName.isEmpty) {
          print('✗ $languageId: displayName must be a non-empty string');
          errorCount++;
        }
      }

      // Validate symbol
      if (data.containsKey('symbol')) {
        final symbol = data['symbol'];
        if (symbol is! String || symbol.isEmpty) {
          print('✗ $languageId: symbol must be a non-empty string');
          errorCount++;
        } else if (!RegExp(r'^[a-zA-Z0-9_.+-]+$').hasMatch(symbol)) {
          print(
            '✗ $languageId: symbol contains invalid characters '
            '(allowed: a-z, A-Z, 0-9, _, ., -, +)',
          );
          errorCount++;
        }
      }

      // Validate scope
      if (data.containsKey('scope')) {
        final scope = data['scope'];
        if (scope is! String || scope.isEmpty) {
          print('✗ $languageId: scope must be a non-empty string');
          errorCount++;
        } else if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9._-]*$').hasMatch(scope)) {
          print(
            '✗ $languageId: scope must start with a letter and contain '
            'only letters, numbers, dots, underscores, and hyphens',
          );
          errorCount++;
        }
      }

      // Validate extensions
      if (data.containsKey('extensions')) {
        final extensions = data['extensions'];
        if (extensions is! List) {
          print('✗ $languageId: extensions must be an array');
          errorCount++;
        } else {
          if (extensions.isEmpty) {
            print('⚠ $languageId: extensions array is empty');
            warningCount++;
          }

          for (var i = 0; i < extensions.length; i++) {
            final ext = extensions[i];
            if (ext is! String) {
              print('✗ $languageId: extensions[$i] must be a string');
              errorCount++;
            } else if (!RegExp(
              r'^\.[.a-zA-Z0-9_-]+$|^[A-Z][a-zA-Z0-9_-]*$',
            ).hasMatch(ext)) {
              print(
                '✗ $languageId: extensions[$i] "$ext" must start with a '
                'dot (e.g., ".js", "..bashrc") or be a filename '
                '(e.g., "Makefile")',
              );
              errorCount++;
            }
          }

          // Check for duplicates
          final uniqueExtensions = extensions.toSet();
          if (uniqueExtensions.length != extensions.length) {
            print('⚠ $languageId: extensions contains duplicates');
            warningCount++;
          }
        }
      }

      // Validate queries (tree-sitter specific, optional)
      if (data.containsKey('queries')) {
        final queries = data['queries'];
        if (queries is! Map<String, dynamic>) {
          print('✗ $languageId: queries must be an object');
          errorCount++;
        } else {
          final validQueryTypes = [
            'highlights',
            'injections',
            'locals',
            'tags',
            'folds',
            'indents',
            'textobjects',
          ];
          for (final queryEntry in queries.entries) {
            final queryType = queryEntry.key;
            final queryValue = queryEntry.value;

            if (!validQueryTypes.contains(queryType)) {
              print(
                '⚠ $languageId: queries["$queryType"] is not a standard '
                'query type',
              );
              warningCount++;
            }

            if (queryValue is! bool) {
              print('✗ $languageId: queries["$queryType"] must be a boolean');
              errorCount++;
            }
          }
        }
      }

      // Validate dylib_dir (tree-sitter specific, optional)
      if (data.containsKey('dylib_dir')) {
        final dylibDir = data['dylib_dir'];
        if (dylibDir is! String || dylibDir.isEmpty) {
          print('✗ $languageId: dylib_dir must be a non-empty string');
          errorCount++;
        }
      }

      // Validate queries_dir (tree-sitter specific, optional)
      if (data.containsKey('queries_dir')) {
        final queriesDir = data['queries_dir'];
        if (queriesDir is! String || queriesDir.isEmpty) {
          print('✗ $languageId: queries_dir must be a non-empty string');
          errorCount++;
        }
      }

      // Validate source (required on every compiled grammar)
      if (isTreeSitterLanguage && !data.containsKey('source')) {
        print('✗ $languageId: Missing required field "source"');
        errorCount++;
      }
      if (data.containsKey('source')) {
        for (final problem in sourceProblems(
          data['source'],
          languageVersions: languageVersions,
        )) {
          print('✗ $languageId: $problem');
          errorCount++;
        }
      }

      // Validate queryOnly
      if (data.containsKey('queryOnly') && data['queryOnly'] is! bool) {
        print('✗ $languageId: queryOnly must be a boolean');
        errorCount++;
      }

      // Validate filenames
      if (data.containsKey('filenames')) {
        final filenames = data['filenames'];
        if (filenames is! List ||
            filenames.any((name) => name is! String || name.isEmpty)) {
          print('✗ $languageId: filenames must be an array of file names');
          errorCount++;
        }
      }

      // Check for unknown fields
      final knownFields = [
        'displayName',
        'symbol',
        'scope',
        'extensions',
        'filenames',
        'queries',
        'queryOnly',
        'dylib_dir',
        'queries_dir',
        'source',
      ];
      for (final field in data.keys) {
        if (!knownFields.contains(field)) {
          print('⚠ $languageId: Unknown field "$field"');
          warningCount++;
        }
      }
    }

    print('');
    print('════════════════════════════════════════════════════════════');
    print('Validation Summary');
    print('════════════════════════════════════════════════════════════');
    print('Total languages: ${manifest.length}');
    print('Errors: $errorCount');
    print('Warnings: $warningCount');
    print('');

    if (errorCount > 0) {
      print('✗ Validation failed');
      exit(1);
    } else if (warningCount > 0) {
      print('⚠ Validation passed with warnings');
      exit(0);
    } else {
      print('✓ Validation passed');
      exit(0);
    }
  } catch (e, stackTrace) {
    print('Error: Failed to parse manifest: $e');
    print(stackTrace);
    exit(1);
  }
}

/// The runtime's language versions as the `build_info.json` beside the
/// manifest at [manifestPath] records them, or null when it records none.
({int current, int minCompatible})? _languageVersions(String manifestPath) {
  final file = File(p.join(p.dirname(manifestPath), 'build_info.json'));
  if (!file.existsSync()) return null;
  final info = jsonDecode(file.readAsStringSync());
  if (info case {
    'treeSitter': {
      'languageVersion': final int current,
      'minCompatibleLanguageVersion': final int minCompatible,
    },
  }) {
    return (current: current, minCompatible: minCompatible);
  }
  return null;
}
