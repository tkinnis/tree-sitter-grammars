import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;

/// Tree-sitter grammar build script.
///
/// Clones grammar repositories, compiles native parser libraries (.dylib/.so/.dll),
/// and generates manifest.json for runtime language loading.
///
/// Query files (.scm) are maintained separately in queries/ and are not part of
/// this build process. Use tool/bootstrap_language.dart to import queries for
/// new languages from nvim-treesitter.
///
/// Usage:
///   dart tool/build_tree_sitter_grammars.dart [options] tool/grammars.json
///
/// Options:
///   --force          Rebuild even if grammar already exists
///   --cleanup        Delete grammars/ directory after build
///   --manifest-only  Only regenerate manifest (no builds)

Future<void> main(List<String> args) async {
  final force = args.contains('--force');
  final cleanup = args.contains('--cleanup');
  final manifestOnly = args.contains('--manifest-only');
  final grammarFile = args.firstWhere(
    (arg) => !arg.startsWith('--'),
    orElse: () => '',
  );

  if (grammarFile.isEmpty) {
    print(
      'Usage: dart tool/build_grammars.dart [--force] [--cleanup] [--manifest-only] <path_to_grammars.json>',
    );
    print('');
    print('Options:');
    print('  --force          Rebuild even if grammar already exists');
    print('  --cleanup        Delete grammars/ directory after build');
    print('  --manifest-only  Only regenerate manifest (no builds)');
    exit(1);
  }

  // Fast path: only regenerate manifest
  if (manifestOnly) {
    await _manifestOnlyMode(grammarFile);
    return;
  }

  // Verify tree-sitter is installed
  final treeSitterPath = await _findTreeSitter();

  // Load grammars configuration
  final grammarsFile = File(grammarFile);
  final grammarsConfig =
      jsonDecode(await grammarsFile.readAsString()) as List<dynamic>;

  // Create output directory
  final outputDir = Directory('output');
  await outputDir.create(recursive: true);

  if (force) {
    print('Cleaning build artifacts (--force)...');
    // Only delete the artifacts we build, not source files like theme_scope_map.json
    final dylibsDir = Directory('${outputDir.path}/dylibs');
    final queriesDir = Directory('${outputDir.path}/queries');
    final manifestFile = File('${outputDir.path}/manifest.json');
    final treeSitterLib = File('${outputDir.path}/libtree-sitter.dylib');

    if (dylibsDir.existsSync()) {
      await dylibsDir.delete(recursive: true);
    }
    if (queriesDir.existsSync()) {
      await queriesDir.delete(recursive: true);
    }
    if (manifestFile.existsSync()) {
      await manifestFile.delete();
    }
    if (treeSitterLib.existsSync()) {
      await treeSitterLib.delete();
    }
  }

  final grammarsDir = Directory('grammars');
  if (!grammarsDir.existsSync()) {
    await grammarsDir.create();
  }

  print(
    '════════════════════════════════════════════════════════════════════════════════',
  );
  print('Tree-sitter Grammar Build');
  print(
    '════════════════════════════════════════════════════════════════════════════════',
  );
  print('');

  // Group by URL to avoid cloning same repo multiple times
  final reposByUrl = <String, List<Map<String, dynamic>>>{};
  for (final config in grammarsConfig) {
    final configMap = config as Map<String, dynamic>;
    // Skip no-op languages (like plaintext) that don't need building
    if (configMap.containsKey('noop') && configMap['noop'] == true) {
      continue;
    }
    // Skip query-only languages (like html_tags, comment) that have no grammar
    if (configMap.containsKey('queryOnly') && configMap['queryOnly'] == true) {
      continue;
    }
    final url = configMap['url'] as String;
    reposByUrl[url] ??= [];
    reposByUrl[url]!.add(configMap);
  }

  print('Found ${reposByUrl.length} repositories to process');
  print('');

  // Clone/update repositories
  print('─' * 80);
  print('Step 1: Cloning/Updating Repositories');
  print('─' * 80);
  print('');

  for (final url in reposByUrl.keys) {
    final repoName = _getRepoNameFromUrl(url);
    final repoDir = Directory('grammars/$repoName');

    if (repoDir.existsSync()) {
      print('Updating $repoName...');
      await Process.run('git', ['pull'], workingDirectory: repoDir.path);
    } else {
      print('Cloning $repoName...');
      final result = await Process.run('git', ['clone', url, repoDir.path]);
      if (result.exitCode != 0) {
        print('  ✗ Failed to clone: ${result.stderr}');
        continue;
      }
    }

    // Run npm install if package.json exists and node_modules doesn't
    final packageJson = File('${repoDir.path}/package.json');
    final nodeModules = Directory('${repoDir.path}/node_modules');
    if (packageJson.existsSync()) {
      if (!nodeModules.existsSync()) {
        print('  Running npm install for $repoName...');
        final npmResult = await Process.run(
          'npm',
          ['install'],
          workingDirectory: repoDir.path,
        );
        if (npmResult.exitCode != 0) {
          print(
            '  ⚠ npm install failed (non-critical, continuing): ${npmResult.stderr.toString().split('\n').first}',
          );
        }
      } else {
        print('  ⊙ Skipping npm install (node_modules exists)');
      }
    }

    print('  ✓ $repoName ready');
  }

  print('');
  print('─' * 80);
  print('Step 2: Verifying Query File Configurations');
  print('─' * 80);
  print('');

  await _verifyQueryConfigurations(reposByUrl, grammarsConfig);

  print('');
  print('─' * 80);
  print('Step 3: Building tree-sitter Core Library');
  print('─' * 80);
  print('');

  // Build the main tree-sitter library
  await _buildTreeSitterLibrary(outputDir);

  print('');
  print('─' * 80);
  print('Step 4: Building Grammars');
  print('─' * 80);
  print('');

  // Load existing manifest if it exists
  final manifestFile = File('${outputDir.path}/manifest.json');
  final manifest = <String, Map<String, dynamic>>{};
  if (manifestFile.existsSync()) {
    try {
      final existingManifest =
          jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
      manifest.addAll(
        existingManifest.map((k, v) => MapEntry(k, v as Map<String, dynamic>)),
      );
      print('Loaded existing manifest with ${manifest.length} grammars');
    } catch (e) {
      print('⚠ Warning: Could not load existing manifest: $e');
    }
  }

  var successCount = 0;
  var skipCount = 0;
  var failCount = 0;

  for (final config in grammarsConfig) {
    final configMap = config as Map<String, dynamic>;
    // Handle plaintext and other no-op languages without URLs
    if (configMap.containsKey('noop') && configMap['noop'] == true) {
      final name = configMap['name'] as String;
      final manifestEntry = <String, dynamic>{
        'displayName': configMap['displayName'] ?? name,
        'scope': configMap['scope'] ?? 'text.$name',
        'extensions': configMap['extensions'] ?? <String>[],
      };
      manifest[name] = manifestEntry;
      print('✓ $name (no-op)');
      successCount++;
      continue;
    }

    // Skip query-only languages (like html_tags, comment) that have no grammar
    if (configMap.containsKey('queryOnly') && configMap['queryOnly'] == true) {
      continue;
    }

    final url = configMap['url'] as String;
    final repoName = _getRepoNameFromUrl(url);
    final repoDir = Directory('grammars/$repoName');

    // Read tree-sitter.json if it exists
    final tsJsonFile = File('${repoDir.path}/tree-sitter.json');
    Map<String, dynamic>? tsJson;
    if (tsJsonFile.existsSync()) {
      tsJson =
          jsonDecode(await tsJsonFile.readAsString()) as Map<String, dynamic>;
    }

    // Determine which grammars to build
    List<Map<String, dynamic>> grammarsToBuild;

    if (configMap.containsKey('name')) {
      // Manual config - highest priority (overrides tree-sitter.json)
      grammarsToBuild = [configMap];
    } else if (configMap.containsKey('grammars')) {
      // Explicit grammar selection from tree-sitter.json
      final selectedNames = (configMap['grammars'] as List).cast<String>();
      if (tsJson != null && tsJson.containsKey('grammars')) {
        final allGrammars =
            (tsJson['grammars'] as List).cast<Map<String, dynamic>>();
        grammarsToBuild = allGrammars
            .where((g) => selectedNames.contains(g['name']))
            .toList();
      } else {
        print(
          '⚠ Warning: grammars specified but no tree-sitter.json found for $repoName',
        );
        continue;
      }
    } else if (tsJson != null && tsJson.containsKey('grammars')) {
      // Build all grammars from tree-sitter.json
      grammarsToBuild =
          (tsJson['grammars'] as List).cast<Map<String, dynamic>>();
    } else {
      print('⚠ Warning: No grammars found for $repoName');
      continue;
    }

    // Build each grammar
    for (final grammar in grammarsToBuild) {
      final grammarName = grammar['name'] as String;

      // Output directory for dynamic library
      final dylibOutputDir = Directory('${outputDir.path}/dylibs/$grammarName');

      // Merge config into grammar for manifest generation
      final mergedGrammar = Map<String, dynamic>.from(grammar);

      // Check if already built (check dylib directory)
      if (dylibOutputDir.existsSync() && !force) {
        print(
          '⊙ Skipping $grammarName (already built, use --force to rebuild)',
        );
        skipCount++;
        // Always regenerate manifest entry (to pick up any query file changes)
        final manifestEntry =
            await _createManifestEntry(mergedGrammar, configMap, grammarName);
        manifest[grammarName] = manifestEntry;
        continue;
      }

      print('Building $grammarName...');

      try {
        // Build grammar
        final buildResult = await _buildGrammar(
          treeSitterPath,
          repoDir.path,
          mergedGrammar,
          grammarName,
          dylibOutputDir,
        );

        if (buildResult) {
          // Generate manifest entry
          final manifestEntry =
              await _createManifestEntry(mergedGrammar, configMap, grammarName);
          manifest[grammarName] = manifestEntry;

          print('  ✓ $grammarName built successfully');
          successCount++;
        } else {
          print('  ✗ $grammarName build failed');
          failCount++;
        }
      } catch (e) {
        print('  ✗ $grammarName error: $e');
        failCount++;
      }
    }
  }

  print('');
  print('─' * 80);
  print('Step 5: Copying Query Files to Grammar Bundles');
  print('─' * 80);
  print('');

  // Copy query files to each grammar's output directory
  await _copyQueryFilesToOutput(manifest, outputDir);

  print('');
  print('─' * 80);
  print('Step 6: Generating Manifest');
  print('─' * 80);
  print('');

  // Write manifest.json
  await manifestFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(manifest),
  );
  print('✓ Wrote manifest.json with ${manifest.length} grammars');

  print('');
  print('─' * 80);
  print('Step 7: Validating Manifest');
  print('─' * 80);
  print('');

  // Validate manifest
  final validateResult = await Process.run(
    'dart',
    ['tool/validate_manifest.dart', manifestFile.path],
  );
  print(validateResult.stdout);
  if (validateResult.exitCode != 0) {
    print('⚠ Manifest validation failed');
  }

  print('');
  print(
    '════════════════════════════════════════════════════════════════════════════════',
  );
  print('Build Summary');
  print(
    '════════════════════════════════════════════════════════════════════════════════',
  );
  print('Successfully built: $successCount grammars');
  print('Skipped (existing): $skipCount grammars');
  print('Failed: $failCount grammars');
  print('Total in manifest: ${manifest.length} grammars');
  print('');

  if (cleanup) {
    print('Cleaning up grammars/ directory (--cleanup)...');
    await grammarsDir.delete(recursive: true);
    print('✓ Cleanup complete');
  }

  print(
    '════════════════════════════════════════════════════════════════════════════════',
  );
}

/// Find tree-sitter CLI
Future<String> _findTreeSitter() async {
  final result = await Process.run('which', ['tree-sitter']);
  if (result.exitCode != 0) {
    print('Error: tree-sitter not found. Please install it:');
    print('  npm install -g tree-sitter-cli');
    exit(1);
  }
  return (result.stdout as String).trim();
}

/// Extract repository name from URL
String _getRepoNameFromUrl(String url) {
  // https://github.com/tree-sitter/tree-sitter-rust -> tree-sitter-rust
  // github.com/foo/bar -> bar
  var name = url.split('/').last;
  if (name.isEmpty) name = url.split('/')[url.split('/').length - 2];
  return name.replaceAll('.git', '');
}

/// Build a single grammar (compiles native library only)
///
/// Query files (.scm) are maintained separately in queries/ and are NOT part
/// of the build process.
Future<bool> _buildGrammar(
  String treeSitterPath,
  String repoPath,
  Map<String, dynamic> grammar,
  String grammarName,
  Directory dylibOutputDir,
) async {
  // Determine grammar path within repo
  final grammarPath = grammar['path'] as String? ?? '.';
  final grammarDir = path.join(repoPath, grammarPath);

  // Generate parser
  print('  Generating parser...');
  final generateResult = await Process.run(
    treeSitterPath,
    ['generate'],
    workingDirectory: grammarDir,
  );
  if (generateResult.exitCode != 0) {
    print('  ✗ Generate failed: ${generateResult.stderr}');
    return false;
  }

  // Compile library directly with clang (not tree-sitter build)
  // This gives us full control over linker flags, which is needed for
  // -headerpad_max_install_names on macOS
  print('  Compiling library...');

  // Create dylib output directory
  await dylibOutputDir.create(recursive: true);

  // Determine library extension
  final libExtension = Platform.isLinux
      ? '.so'
      : Platform.isMacOS
          ? '.dylib'
          : '.dll';

  final srcDir = Directory(path.join(grammarDir, 'src'));
  final parserFile = File(path.join(srcDir.path, 'parser.c'));
  final scannerCFile = File(path.join(srcDir.path, 'scanner.c'));
  final scannerCcFile = File(path.join(srcDir.path, 'scanner.cc'));

  if (!parserFile.existsSync()) {
    print('  ✗ parser.c not found at: ${parserFile.path}');
    return false;
  }

  final destLib = File('${dylibOutputDir.path}/lib$grammarName$libExtension');
  final compiler = Platform.environment['CC'] ?? 'clang';

  // Build compiler arguments
  final args = <String>[
    '-shared', // Create shared library
    '-fPIC', // Position Independent Code
    '-I', srcDir.path, // Include src directory
    '-O3', // Optimization
    '-o', destLib.path, // Output file
    if (Platform.isMacOS) ...[
      '-headerpad_max_install_names', // Allow install_name_tool to rewrite paths
      '-undefined', 'dynamic_lookup', // Allow unresolved symbols (standard for plugins)
      '-install_name', '@rpath/lib$grammarName.dylib', // Set install name
    ],
    parserFile.path,
  ];

  // Add scanner if present (check both .c and .cc)
  if (scannerCFile.existsSync()) {
    args.add(scannerCFile.path);
  } else if (scannerCcFile.existsSync()) {
    // For C++ scanners, use clang++
    args.add(scannerCcFile.path);
    args.addAll(['-lstdc++']); // Link C++ standard library
  }

  final buildResult = await Process.run(compiler, args);
  if (buildResult.exitCode != 0) {
    print('  ✗ Compile failed: ${buildResult.stderr}');
    return false;
  }

  if (!destLib.existsSync()) {
    print('  ✗ Compiled library not found at: ${destLib.path}');
    return false;
  }

  return true;
}

/// Create manifest entry for a grammar
Future<Map<String, dynamic>> _createManifestEntry(
  Map<String, dynamic> grammar,
  Map<String, dynamic> config,
  String grammarName,
) async {
  // Get display name
  final displayName = config['displayName'] as String? ??
      grammar['camelcase'] as String? ??
      grammar['camel-case-name'] as String? ??
      _capitalize(grammarName);

  // Get scope
  final scope = config['scope'] as String? ??
      grammar['scope'] as String? ??
      'source.$grammarName';

  // Get file extensions
  final fileTypes = config['file-types'] as List<dynamic>? ??
      grammar['file-types'] as List<dynamic>? ??
      [grammarName];

  final extensions = fileTypes.map((e) => '.$e').toList();

  // Get filenames (for files without extensions like 'Makefile')
  final filenames = config['filenames'] as List<dynamic>?;

  // Check which query files actually exist in the output directory
  final queryAvailability = <String, bool>{};
  final queryTypes = [
    'highlights',
    'injections',
    'locals',
    'tags',
    'folds',
    'indents',
    'textobjects',
  ];
  final queriesDir = Directory('queries/$grammarName');

  for (final queryType in queryTypes) {
    final queryFile = File('${queriesDir.path}/$queryType.scm');
    queryAvailability[queryType] = queryFile.existsSync();
  }

  // Convert hyphens to underscores for symbol name (C function names can't have hyphens)
  final symbolName = grammarName.replaceAll('-', '_');

  // Add paths to directories (relative to output/)
  final dylibDir = 'dylibs/$grammarName';
  final queriesDirPath = 'queries/$grammarName';

  final entry = {
    'displayName': displayName,
    'symbol': symbolName,
    'scope': scope,
    'extensions': extensions,
    'dylib_dir': dylibDir,
    'queries_dir': queriesDirPath,
    'queries': queryAvailability,
  };

  // Add filenames if specified
  if (filenames != null && filenames.isNotEmpty) {
    entry['filenames'] = filenames;
  }

  return entry;
}

String _capitalize(String s) {
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}

/// Build the main tree-sitter library and copy it to the output directory
Future<void> _buildTreeSitterLibrary(Directory outputDir) async {
  final treeSitterDir = Directory('tree-sitter');

  if (!treeSitterDir.existsSync()) {
    print('⚠ tree-sitter directory not found, skipping core library build');
    return;
  }

  print('Building tree-sitter core library...');

  final libExtension = Platform.isLinux
      ? '.so'
      : Platform.isMacOS
          ? '.dylib'
          : '.dll';

  final libName = 'libtree-sitter$libExtension';
  final sourceLib = File('${treeSitterDir.path}/$libName');
  final destLib = File('${outputDir.path}/$libName');

  // Check if library already exists in tree-sitter directory
  if (sourceLib.existsSync()) {
    print('  Found existing $libName in tree-sitter directory');
  } else {
    // Build using make
    print('  Running make...');

    // On macOS, add headerpad flag so install_name_tool can rewrite paths later
    final environment = Platform.isMacOS
        ? {'LDFLAGS': '-headerpad_max_install_names'}
        : <String, String>{};

    final buildResult = await Process.run(
      'make',
      [],
      workingDirectory: treeSitterDir.path,
      environment: environment,
    );

    if (buildResult.exitCode != 0) {
      print('  ✗ Build failed: ${buildResult.stderr}');
      return;
    }

    if (!sourceLib.existsSync()) {
      print('  ✗ Compiled library not found at: ${sourceLib.path}');
      return;
    }
  }

  // Copy to output directory
  await sourceLib.copy(destLib.path);

  // On macOS, fix the install name to use @rpath for portability
  if (Platform.isMacOS) {
    final newId = '@rpath/libtree-sitter.dylib';
    final result = await Process.run('install_name_tool', [
      '-id',
      newId,
      destLib.path,
    ]);
    if (result.exitCode != 0) {
      print('  ⚠ Warning: Could not set install name: ${result.stderr}');
    }
  }

  print('  ✓ tree-sitter core library copied to ${destLib.path}');
}

/// Verify that query file configurations match what's actually in the repositories
Future<void> _verifyQueryConfigurations(
  Map<String, List<Map<String, dynamic>>> reposByUrl,
  List<dynamic> grammarsConfig,
) async {
  final queryTypes = [
    'highlights',
    'injections',
    'locals',
    'tags',
    'folds',
    'indents',
    'textobjects',
  ];
  var issueCount = 0;

  for (final config in grammarsConfig) {
    final configMap = config as Map<String, dynamic>;
    final url = configMap['url'] as String?;
    if (url == null) continue;
    final repoName = _getRepoNameFromUrl(url);
    final repoDir = Directory('grammars/$repoName');

    if (!repoDir.existsSync()) {
      continue;
    }

    // Read tree-sitter.json if it exists
    final tsJsonFile = File('${repoDir.path}/tree-sitter.json');
    Map<String, dynamic>? tsJson;
    if (tsJsonFile.existsSync()) {
      try {
        tsJson =
            jsonDecode(await tsJsonFile.readAsString()) as Map<String, dynamic>;
      } catch (e) {
        // Ignore parse errors
      }
    }

    // Determine which grammars to check
    List<Map<String, dynamic>> grammarsToCheck;

    if (configMap.containsKey('name')) {
      grammarsToCheck = [configMap];
    } else if (configMap.containsKey('grammars')) {
      final selectedNames = (configMap['grammars'] as List).cast<String>();
      if (tsJson != null && tsJson.containsKey('grammars')) {
        final allGrammars =
            (tsJson['grammars'] as List).cast<Map<String, dynamic>>();
        grammarsToCheck = allGrammars
            .where((g) => selectedNames.contains(g['name']))
            .toList();
      } else {
        grammarsToCheck = <Map<String, dynamic>>[];
      }
    } else if (tsJson != null && tsJson.containsKey('grammars')) {
      grammarsToCheck =
          (tsJson['grammars'] as List).cast<Map<String, dynamic>>();
    } else {
      grammarsToCheck = <Map<String, dynamic>>[];
    }

    for (final grammar in grammarsToCheck) {
      final grammarName = grammar['name'] as String;

      // Create merged grammar to see final query configuration
      final mergedGrammar = Map<String, dynamic>.from(grammar);
      for (final queryType in queryTypes) {
        if (configMap.containsKey(queryType) &&
            !mergedGrammar.containsKey(queryType)) {
          mergedGrammar[queryType] = configMap[queryType];
        }
      }

      // Check if any query paths are actually configured
      final hasAnyQueryPaths =
          queryTypes.any((type) => mergedGrammar.containsKey(type));

      if (!hasAnyQueryPaths) {
        // No queries configured, skip verification
        continue;
      }

      // Verify that configured query paths exist
      final grammarPath = grammar['path'] as String? ?? '.';
      final fullGrammarPath = path.join(repoDir.path, grammarPath);

      // Find all queries directories - check both grammar path and repo root
      final possibleQueryDirs = [
        Directory('$fullGrammarPath/queries'),
        Directory('${repoDir.path}/queries'),
      ];

      Directory? queriesDir;
      for (final dir in possibleQueryDirs) {
        if (dir.existsSync()) {
          queriesDir = dir;
          break;
        }
      }

      // List all .scm files in queries directory if it exists
      final scmFiles = <String>[];
      if (queriesDir != null) {
        await for (final entity in queriesDir.list()) {
          if (entity is File && entity.path.endsWith('.scm')) {
            scmFiles.add(path.basename(entity.path));
          }
        }
      }

      // Check if all available query files are configured
      final missingConfigs = <String>[];
      for (final scmFile in scmFiles) {
        // Remove .scm extension to get query type
        final queryType = scmFile.replaceAll('.scm', '');

        // Skip non-standard query types
        if (!queryTypes.contains(queryType)) {
          continue;
        }

        // Check if this query type is configured
        if (!mergedGrammar.containsKey(queryType)) {
          missingConfigs.add(queryType);
        }
      }

      // Check if configured queries actually exist
      final invalidConfigs = <String>[];
      for (final queryType in queryTypes) {
        if (mergedGrammar.containsKey(queryType)) {
          final queryValue = mergedGrammar[queryType];
          List<String> queryPaths;

          if (queryValue is String) {
            queryPaths = [queryValue];
          } else if (queryValue is List) {
            queryPaths = queryValue.cast<String>();
          } else {
            continue;
          }

          // Check if any of the configured paths exist
          var pathExists = false;
          for (final queryPath in queryPaths) {
            final fullPath = path.join(repoDir.path, queryPath);
            if (File(fullPath).existsSync()) {
              pathExists = true;
              break;
            }
          }

          if (!pathExists) {
            invalidConfigs.add('$queryType (${queryPaths.join(', ')})');
          }
        }
      }

      // Report issues
      if (missingConfigs.isNotEmpty || invalidConfigs.isNotEmpty) {
        print('⚠ $grammarName: Query configuration issues detected');
        print('  → Repository: $repoName');

        if (invalidConfigs.isNotEmpty) {
          print('  → Invalid paths (files not found):');
          for (final invalid in invalidConfigs) {
            print('      - $invalid');
          }
          print('  → Action: Remove or fix these entries in grammars.json');
        }

        if (missingConfigs.isNotEmpty) {
          print('  → Missing configurations (files exist but not configured):');
          for (final missing in missingConfigs) {
            print('      - $missing (found: queries/$missing.scm)');
          }
          print('  → Action: Add these entries to grammars.json if needed:');
          print(
            '      "${missingConfigs.map((m) => '"$m": "queries/$m.scm"').join(', ')}"',
          );
        }

        issueCount++;
        print('');
      }
    }
  }

  if (issueCount == 0) {
    print('✓ All query file configurations verified');
  } else {
    print('Found $issueCount grammar(s) with query configuration issues');
    print('Review the messages above and update grammars.json as needed');
  }
}

/// Manifest-only mode: only regenerate manifest without rebuilding
Future<void> _manifestOnlyMode(String grammarFile) async {
  print(
    '════════════════════════════════════════════════════════════════════════════════',
  );
  print('Manifest-Only Mode (Fastest)');
  print(
    '════════════════════════════════════════════════════════════════════════════════',
  );
  print('');

  // Load grammars configuration
  final grammarsConfig =
      jsonDecode(await File(grammarFile).readAsString()) as List<dynamic>;

  final manifest = <String, Map<String, dynamic>>{};

  print('Regenerating manifest entries from grammars.json...');
  print('');

  for (final config in grammarsConfig) {
    final configMap = config as Map<String, dynamic>;
    // Handle plaintext and other no-op languages without URLs
    if (configMap.containsKey('noop') && configMap['noop'] == true) {
      final name = configMap['name'] as String;
      final manifestEntry = <String, dynamic>{
        'displayName': configMap['displayName'] ?? name,
        'scope': configMap['scope'] ?? 'text.$name',
        'extensions': configMap['extensions'] ?? <String>[],
      };
      manifest[name] = manifestEntry;
      print('✓ $name (no-op)');
      continue;
    }

    // Handle query-only languages (e.g., comment)
    if (configMap['queryOnly'] == true) {
      final name = configMap['name'] as String;
      final manifestEntry = <String, dynamic>{
        'displayName': configMap['displayName'] as String? ?? _capitalize(name),
        'scope': configMap['scope'] as String? ?? 'source.$name',
        'extensions': configMap['extensions'] ?? <String>[],
        'queryOnly': true,
        'queries_dir': 'queries/$name',
        'queries': configMap['queries'] ??
            <String, bool>{
              'highlights': true,
              'injections': false,
              'locals': false,
              'tags': false,
              'folds': false,
              'indents': false,
              'textobjects': false,
            },
      };
      manifest[name] = manifestEntry;
      print('✓ $name (query-only)');
      continue;
    }

    final url = configMap['url'] as String?;
    if (url == null) {
      print('⚠ Skipping config: no url specified');
      continue;
    }
    final repoName = _getRepoNameFromUrl(url);
    final repoDir = Directory('grammars/$repoName');

    // Read tree-sitter.json if it exists
    final tsJsonFile = File('${repoDir.path}/tree-sitter.json');
    Map<String, dynamic>? tsJson;
    if (tsJsonFile.existsSync()) {
      try {
        tsJson =
            jsonDecode(await tsJsonFile.readAsString()) as Map<String, dynamic>;
      } catch (e) {
        // Ignore parse errors
      }
    }

    // Determine which grammars to process
    List<Map<String, dynamic>> grammarsToProcess;

    if (configMap.containsKey('name')) {
      grammarsToProcess = [configMap];
    } else if (configMap.containsKey('grammars')) {
      final selectedNames = (configMap['grammars'] as List).cast<String>();
      if (tsJson != null && tsJson.containsKey('grammars')) {
        final allGrammars =
            (tsJson['grammars'] as List).cast<Map<String, dynamic>>();
        grammarsToProcess = allGrammars
            .where((g) => selectedNames.contains(g['name']))
            .toList();
      } else {
        grammarsToProcess = <Map<String, dynamic>>[];
      }
    } else if (tsJson != null && tsJson.containsKey('grammars')) {
      grammarsToProcess =
          (tsJson['grammars'] as List).cast<Map<String, dynamic>>();
    } else {
      grammarsToProcess = <Map<String, dynamic>>[];
    }

    for (final grammar in grammarsToProcess) {
      final grammarName = grammar['name'] as String;

      // Merge config into grammar
      final mergedGrammar = Map<String, dynamic>.from(grammar);
      final queryTypes = [
        'highlights',
        'injections',
        'locals',
        'tags',
        'folds',
        'indents',
        'textobjects',
      ];
      for (final queryType in queryTypes) {
        if (configMap.containsKey(queryType) &&
            !mergedGrammar.containsKey(queryType)) {
          mergedGrammar[queryType] = configMap[queryType];
        }
      }

      // Generate manifest entry
      final manifestEntry =
          await _createManifestEntry(mergedGrammar, configMap, grammarName);
      manifest[grammarName] = manifestEntry;
      print('✓ $grammarName');
    }
  }

  print('');
  print('Copying query files to grammar bundles...');

  // Copy query files to each grammar's output directory
  final outputDir = Directory('output');
  await _copyQueryFilesToOutput(manifest, outputDir);

  print('');
  print('Writing manifest.json...');

  // Write manifest.json
  final manifestFile = File('output/manifest.json');
  await manifestFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(manifest),
  );
  print('✓ Wrote manifest.json with ${manifest.length} grammars');

  print('');
  print('Validating manifest...');

  // Validate manifest
  final validateResult = await Process.run(
    'dart',
    ['tool/validate_manifest.dart', manifestFile.path],
  );
  print(validateResult.stdout);

  print('');
  print(
    '════════════════════════════════════════════════════════════════════════════════',
  );
  print('Manifest Regenerated');
  print(
    '════════════════════════════════════════════════════════════════════════════════',
  );
  print('Total grammars: ${manifest.length}');
  print('');
  print('✅ Done! Manifest updated successfully');
  print(
    '════════════════════════════════════════════════════════════════════════════════',
  );
}

/// Copies query files from queries/ to each grammar's output directory.
///
/// This creates self-contained grammar bundles that include:
/// - The compiled library (lib{lang}.dylib/.so/.dll) for regular grammars
/// - All query files (highlights.scm, injections.scm, etc.)
/// - A config.json with language metadata
///
/// Query-only grammars (like html_tags, comment) are also handled - they get
/// their query files copied to output/queries/{name}/ so they can be used
/// for query inheritance (e.g., `; inherits: html_tags`).
///
/// The bundle structure matches the user grammar format for consistency.
Future<void> _copyQueryFilesToOutput(
  Map<String, Map<String, dynamic>> manifest,
  Directory outputDir,
) async {
  final queriesSourceDir = Directory('queries');
  if (!queriesSourceDir.existsSync()) {
    print('⚠ queries/ directory not found, skipping query file copy');
    return;
  }

  var copiedCount = 0;
  var skippedCount = 0;
  var queryOnlyCount = 0;

  for (final entry in manifest.entries) {
    final grammarName = entry.key;
    final grammarData = entry.value;

    // Handle query-only grammars (like html_tags, comment)
    // These need their queries copied to output/queries/{name}/ for inheritance
    if (grammarData['queryOnly'] == true) {
      final sourceQueryDir = Directory(path.join('queries', grammarName));
      final destDir =
          Directory(path.join(outputDir.path, 'queries', grammarName));

      if (!sourceQueryDir.existsSync()) {
        print('  ⊙ $grammarName (query-only): no query files found');
        skippedCount++;
        continue;
      }

      if (!destDir.existsSync()) {
        await destDir.create(recursive: true);
      }

      // Copy all .scm files
      final scmFiles = <String>[];
      await for (final entity in sourceQueryDir.list()) {
        if (entity is File && entity.path.endsWith('.scm')) {
          final filename = path.basename(entity.path);
          final destFile = File(path.join(destDir.path, filename));
          await entity.copy(destFile.path);
          scmFiles.add(filename);
        }
      }

      // Generate config.json for query-only grammar
      final bundleConfig = <String, dynamic>{
        'displayName': grammarData['displayName'],
        'scope': grammarData['scope'],
        'extensions': grammarData['extensions'],
        'queryOnly': true,
      };

      // Add query availability info
      final queries = grammarData['queries'] as Map<String, dynamic>?;
      if (queries != null) {
        bundleConfig['queries'] = queries;
      }

      final configFile = File(path.join(destDir.path, 'config.json'));
      await configFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(bundleConfig),
      );

      print(
        '  ✓ $grammarName (query-only): ${scmFiles.length} query files + config.json',
      );
      queryOnlyCount++;
      continue;
    }

    // Skip no-op languages like plaintext (no dylib_dir and not query-only)
    if (!grammarData.containsKey('dylib_dir')) {
      skippedCount++;
      continue;
    }

    final sourceQueryDir = Directory(path.join('queries', grammarName));
    final destDir = Directory(path.join(outputDir.path, 'dylibs', grammarName));

    if (!sourceQueryDir.existsSync()) {
      // Try query-only directory
      final queriesDir = grammarData['queries_dir'] as String?;
      if (queriesDir == null) {
        print('  ⊙ $grammarName: no query files found');
        skippedCount++;
        continue;
      }
    }

    if (!destDir.existsSync()) {
      await destDir.create(recursive: true);
    }

    // Copy all .scm files
    final scmFiles = <String>[];
    if (sourceQueryDir.existsSync()) {
      await for (final entity in sourceQueryDir.list()) {
        if (entity is File && entity.path.endsWith('.scm')) {
          final filename = path.basename(entity.path);
          final destFile = File(path.join(destDir.path, filename));
          await entity.copy(destFile.path);
          scmFiles.add(filename);
        }
      }
    }

    // Generate config.json for this grammar bundle
    final bundleConfig = <String, dynamic>{
      'displayName': grammarData['displayName'],
      'symbol': grammarData['symbol'],
      'scope': grammarData['scope'],
      'extensions': grammarData['extensions'],
    };

    // Add filenames if present
    if (grammarData.containsKey('filenames')) {
      bundleConfig['filenames'] = grammarData['filenames'];
    }

    // Add query availability info
    final queries = grammarData['queries'] as Map<String, dynamic>?;
    if (queries != null) {
      bundleConfig['queries'] = queries;
    }

    final configFile = File(path.join(destDir.path, 'config.json'));
    await configFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(bundleConfig),
    );

    print('  ✓ $grammarName: ${scmFiles.length} query files + config.json');
    copiedCount++;
  }

  print('');
  print('Copied query files to $copiedCount grammar bundles');
  if (queryOnlyCount > 0) {
    print('Copied $queryOnlyCount query-only grammars (for inheritance)');
  }
  if (skippedCount > 0) {
    print('Skipped $skippedCount grammars (no query files or no-op)');
  }
}
