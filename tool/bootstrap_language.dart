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
/// whose other spelling, one nvim-treesitter names the same, such as
/// `c_sharp` for `c-sharp`, has a directory under `queries/`. It refuses a
/// language that already has a `queries/<name>/` directory unless
/// `--force` is given; `--force` replaces only what a bootstrap wrote
/// there, removes an earlier unchanged import of a query type the commit
/// no longer has, and refuses a file that holds other work. It prints
/// every file and provenance entry before writing them; `--dry-run` writes
/// none of them.
///
/// Its limits:
///
/// - It knows one language whose name differs from nvim-treesitter's:
///   `c-sharp`, which nvim-treesitter names `c_sharp`. A grammar named
///   differently in any other way needs an entry in the alias table in
///   `tool/src/query_bootstrap.dart`, both for its queries to be found and
///   for its other spelling to be refused.
/// - It imports the five query types above and no other file: `tags.scm`
///   is a placeholder to fill, and textobjects are left out.
/// - It copies each file as nvim-treesitter has it and compiles none of
///   them. nvim-treesitter's own predicates and directives, and
///   `; inherits:` lines naming a language this repository lacks, pass
///   through as they are; `tool/check_release.dart` compiles the files
///   when the grammar is built.
/// - The `config.json` skeleton is a guess: a display name made from the
///   id, one extension named after it, C-style comments and the common
///   brackets.
/// - It neither adds the grammar to `tool/grammars.json`, nor pins it, nor
///   regenerates `THIRD_PARTY_NOTICES.md`; the steps it prints name those.
/// - Every run fetches from nvim-treesitter, a dry run included, so it
///   needs the network.
/// - Runs at once stage their files apart, but each rewrites
///   `tool/query_provenance.json`, and its check that nothing changed
///   since planning is not atomic with the rename. When two runs write at
///   the same moment, the later one's file can drop the earlier one's
///   entries, which rerunning that bootstrap with `--force` restores. Run
///   one bootstrap at a time.
/// - A run killed while writing leaves its `.cache/bootstrap-staging-*`
///   directory behind. No later run removes it; delete it by hand when no
///   bootstrap is running.
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
