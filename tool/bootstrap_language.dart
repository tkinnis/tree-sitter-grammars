/// Imports a new language's query files from nvim-treesitter, recording the
/// nvim-treesitter commit they come from.
///
/// Usage:
///
/// ```sh
/// dart run tool/bootstrap_language.dart --language=<name>
///     [--commit=<sha>] [--force] [--dry-run]
/// ```
///
/// It fetches nvim-treesitter's `HEAD` and branches into the object store
/// `.cache/nvim-treesitter`, with git's user and system configuration shut
/// out, and reads the language's highlights, folds, injections, locals and
/// indents queries at `HEAD`, or at the 40-hex `--commit`, which one of
/// nvim-treesitter's branches must contain, from `runtime/queries/<name>/`
/// or, in a commit from before the queries moved, `queries/<name>/`. Each
/// file is written to `queries/<name>/` under the header that names its
/// nvim-treesitter path and commit, and its `tool/query_provenance.json`
/// entry records the same, unchanged. A `tags.scm` placeholder, with the
/// provenance of a file written here, and a `config.json` skeleton are
/// written when absent.
///
/// Everything is read and checked before anything is written, so a refused
/// run writes nothing under `queries/` or `tool/`. It refuses a language
/// that already has a `queries/<name>/` directory unless `--force` is
/// given; `--force` replaces only what a bootstrap wrote there, removes an
/// earlier unchanged import of a query type the commit no longer has, and
/// refuses a file that holds other work. It prints every file and
/// provenance entry before writing them; `--dry-run` writes none of them.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'src/query_bootstrap.dart';

const _usage =
    'usage: dart run tool/bootstrap_language.dart --language=<name> '
    '[--commit=<sha>] [--force] [--dry-run]';

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    print(_usage);
    return;
  }
  final request = parseBootstrapArguments(args);
  if (request == null) {
    stderr.writeln(_usage);
    exit(64);
  }
  final root = p.dirname(p.dirname(p.fromUri(Platform.script)));
  try {
    await bootstrap(
      root: root,
      request: request,
      beforeWriting: (plan) => _printPlan(plan, dryRun: request.dryRun),
    );
  } on Exception catch (error) {
    stderr.writeln('✗ $error');
    exit(1);
  }
  if (!request.dryRun) _printNextSteps(request.language);
}

void _printPlan(BootstrapPlan plan, {required bool dryRun}) {
  final verb = dryRun ? 'would' : 'will';
  print('nvim-treesitter ${plan.commit}');
  for (final file in plan.files.keys) {
    print('  $verb write $file');
  }
  for (final file in plan.removals) {
    print('  $verb remove $file, which that commit no longer has');
  }
  print('  $verb record in tool/query_provenance.json:');
  for (final MapEntry(key: file, value: entry) in plan.entries.entries) {
    print('    $file: ${jsonEncode(entry)}');
  }
}

void _printNextSteps(String language) {
  print('''
Next steps:
  1. Edit queries/$language/config.json: extensions, comments, brackets.
  2. Adapt the imported queries. For every file you change, set
     "changed": true in tool/query_provenance.json, then run
     dart run tool/check_query_provenance.dart --write-headers
  3. Add symbol patterns to queries/$language/tags.scm.
  4. Add the grammar to tool/grammars.json with its url and license, then
     dart run tool/pin_grammars.dart --set <repository>=<sha>
  5. dart run tool/write_notices.dart
  6. dart run tool/build_tree_sitter_grammars.dart''');
}
