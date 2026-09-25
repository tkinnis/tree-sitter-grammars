import 'dart:io';

import 'package:checks/checks.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../tool/src/files_digest.dart';
import '../tool/src/generated_sources.dart';
import '../tool/src/grammar_plan.dart';
import '../tool/src/source_bundles.dart';

const _commit = '0123456789abcdef0123456789abcdef01234567';

void main() {
  late Directory temporary;

  setUp(() => temporary = Directory.systemTemp.createTempSync('generated'));
  tearDown(() => temporary.deleteSync(recursive: true));

  String path(String relative) => p.join(temporary.path, relative);

  /// A generated directory `gen/swift` like the CLI writes.
  String generate() {
    for (final (file, text) in [
      ('parser.c', 'int parse(void);\n'),
      ('node-types.json', '[]\n'),
      ('tree_sitter/parser.h', '#define TS 1\n'),
    ]) {
      File(path('gen/swift/$file'))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(text);
    }
    return path('gen/swift');
  }

  GrammarBuild build(String? generatedSha256) {
    final entry = <String, Object?>{
      'url': 'https://github.com/example/tree-sitter-swift',
      'commit': _commit,
      'generate': true,
      'generatedSha256': ?generatedSha256,
    };
    return GrammarBuild(
      name: 'swift',
      entry: entry,
      metadata: entry,
      path: '.',
    );
  }

  test('packs the same files into the same bytes, and back', () async {
    final directory = generate();
    final digest = await filesDigest(await unpackedFiles(directory));

    await packGenerated(directory, path('a/swift.tar.gz'));
    await packGenerated(directory, path('b/swift.tar.gz'));
    await unpackBundle(path('a/swift.tar.gz'), path('unpacked'));

    check(
      File(path('a/swift.tar.gz')).readAsBytesSync(),
    ).deepEquals(File(path('b/swift.tar.gz')).readAsBytesSync());
    check(
      await filesDigest(await unpackedFiles(path('unpacked'))),
    ).equals(digest);
  });

  test('requires the files to have the recorded generatedSha256', () async {
    final directory = generate();
    final digest = await filesDigest(await unpackedFiles(directory));

    await requireGenerated(build(digest), directory, 'hint');
    File(p.join(directory, 'parser.c')).writeAsStringSync('int parse(int);\n');

    await check(
      requireGenerated(build(digest), directory, 'hint'),
    ).throws<GeneratedSourcesException>(
      (it) => it.has((e) => e.message, 'message')
        ..contains('grammars.json records $digest')
        ..endsWith('hint'),
    );
  });

  test('checks a downloaded bundle against its build_info record', () async {
    final name = generatedBundleName('swift', _commit);
    await packGenerated(generate(), path('assets/$name'));
    final sha256 = await fileSha256(path('assets/$name'));
    Map<String, Object?> recorded(String digest) => {
      'swift': {
        'commit': _commit,
        'file': '$sourcesDirectoryName/$name',
        'sha256': digest,
      },
    };

    check(
      await checkRecordedGenerated(
        path('assets'),
        build(null),
        recorded(sha256),
      ),
    ).equals(sha256);
    await check(
      checkRecordedGenerated(path('assets'), build(null), recorded('0' * 64)),
    ).throws<GeneratedSourcesException>(
      (it) => it.has((e) => e.message, 'message').contains('has sha256'),
    );
    await check(
      checkRecordedGenerated(path('assets'), build(null), const {}),
    ).throws<GeneratedSourcesException>(
      (it) => it
          .has((e) => e.message, 'message')
          .contains('records no generated bundle'),
    );
  });
}
