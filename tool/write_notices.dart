/// Writes `THIRD_PARTY_NOTICES.md` from the pinned sources, the query
/// provenance and the licences in this repository.
///
/// Usage:
///
/// ```sh
/// dart run tool/write_notices.dart           # write the file
/// dart run tool/write_notices.dart --check   # exit 1 unless it is current
/// ```
///
/// The runtime and every grammar are unpacked at their pins into a
/// temporary directory, as the build unpacks them, so the text is the one
/// the build produces and requires. Commit the written file: the build
/// refuses to run while the committed copy differs from what it produces.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import 'src/grammar_pins.dart';
import 'src/grammar_plan.dart';
import 'src/grammar_sources.dart';
import 'src/notices.dart';
import 'src/query_provenance.dart';
import 'src/toolchain.dart';

Future<void> main(List<String> args) async {
  final check = switch (args) {
    [] => false,
    ['--check'] => true,
    _ => null,
  };
  if (check == null) {
    stderr.writeln('usage: dart run tool/write_notices.dart [--check]');
    exit(64);
  }
  final root = p.dirname(p.dirname(p.fromUri(Platform.script)));
  final temporary = Directory.systemTemp.createTempSync('write_notices');
  try {
    final notices = await generateNotices(root, temporary.path);
    final file = File(p.join(root, noticesFileName));
    final current = file.existsSync() && file.readAsStringSync() == notices;
    if (check) {
      print(
        current
            ? '$noticesFileName is current'
            : '$noticesFileName differs from what the pinned sources produce',
      );
      if (!current) exitCode = 1;
    } else if (current) {
      print('$noticesFileName is current');
    } else {
      file.writeAsStringSync(notices);
      print('wrote $noticesFileName');
    }
  } on Exception catch (error) {
    stderr.writeln('✗ $error');
    exitCode = 1;
  } finally {
    temporary.deleteSync(recursive: true);
  }
}

/// The notices for the repository at [root], unpacking every pinned source
/// under [scratch].
Future<String> generateNotices(String root, String scratch) async {
  final toolchain = Toolchain.load(root);
  final entries = parseGrammars(
    File(p.join(root, 'tool', 'grammars.json')).readAsStringSync(),
  );
  final sourceRoot = p.join(scratch, 'build', 'src');
  await supplySources(
    root: root,
    toolchain: toolchain,
    entries: entries,
    sourceRoot: sourceRoot,
    bundleDirectory: p.join(scratch, 'sources'),
  );
  return thirdPartyNotices(
    NoticesInput(
      toolchain: toolchain,
      runtimeDirectory: p.join(sourceRoot, 'tree-sitter'),
      entries: entries,
      builds: planGrammars(scratch, entries),
      sourceRoot: sourceRoot,
      provenance: readRepositoryProvenance(root),
      apacheLicense: File(
        p.join(root, 'LICENSES', 'Apache-2.0.txt'),
      ).readAsStringSync(),
      ownLicense: File(p.join(root, 'LICENSE')).readAsStringSync(),
    ),
  );
}
