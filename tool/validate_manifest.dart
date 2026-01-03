import 'dart:convert';
import 'dart:io';

/// Validates a language manifest against the JSON schema
///
/// This provides basic validation since Dart doesn't have great JSON Schema support.
/// For full validation, use a tool like `ajv-cli`:
///   npm install -g ajv-cli
///   ajv validate -s tool/manifest_schema.json -d output/manifest.json
void main(List<String> args) {
  if (args.isEmpty) {
    print('Usage: dart tool/validate_manifest.dart <manifest_path>');
    print(
      'Example: dart tool/validate_manifest.dart output/manifest.json',
    );
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

      // Check required fields
      // Note: 'symbol' is only required for tree-sitter languages (those with dylib_dir)
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
            '✗ $languageId: symbol contains invalid characters (allowed: a-z, A-Z, 0-9, _, ., -, +)',
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
            '✗ $languageId: scope must start with a letter and contain only letters, numbers, dots, underscores, and hyphens',
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
            } else if (!RegExp(r'^\.[.a-zA-Z0-9_-]+$|^[A-Z][a-zA-Z0-9_-]*$')
                .hasMatch(ext)) {
              print(
                '✗ $languageId: extensions[$i] "$ext" must start with a dot (e.g., ".js", "..bashrc") or be a filename (e.g., "Makefile")',
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
                '⚠ $languageId: queries["$queryType"] is not a standard query type',
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

      // Check for unknown fields
      final knownFields = [
        'displayName',
        'symbol',
        'scope',
        'extensions',
        'filenames',
        'queries',
        'dylib_dir',
        'queries_dir',
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
