import 'dart:io';

import 'package:checks/checks.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../tool/src/release_check.dart';

void main() {
  group('apiFunctions', () {
    test('lists each declared function once, ignoring comments', () {
      const header = '''
/* ts_commented_out(void) */
// ts_line_comment(void)
TSParser *ts_parser_new(void);
void ts_parser_delete(
  TSParser *self
);
#define TS_MACRO(x) ts_parser_new(x)
''';

      check(
        apiFunctions(header),
      ).deepEquals(['ts_parser_delete', 'ts_parser_new']);
    });
  });

  group('composeQuery', () {
    late Directory archive;

    setUp(() => archive = Directory.systemTemp.createTempSync('compose'));
    tearDown(() => archive.deleteSync(recursive: true));

    void write(String relative, String text) =>
        File(p.join(archive.path, relative))
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(text);

    String compose(String language) =>
        composeQuery(p.join(archive.path, 'dylibs', language), 'h.scm')!;

    test('reads a file with no inherits line as it is', () {
      write('dylibs/c/h.scm', '; header\n(a) @x\n');

      check(compose('c')).equals('; header\n(a) @x\n');
    });

    test('puts inherited text first, from a sibling or queries/', () {
      write('dylibs/tsx/h.scm', '; header\n; inherits: typescript,jsx\n(t)');
      write('dylibs/typescript/h.scm', '; inherits: ecma\n(ts)');
      write('queries/ecma/h.scm', '(e)');
      write('queries/jsx/h.scm', '(j)');

      check(compose('tsx')).equals('(e)\n\n(ts)\n\n(j)\n\n; header\n\n(t)');
    });

    test('a sibling wins over queries/, and a missing parent is skipped', () {
      write('dylibs/a/h.scm', '; inherits: b, missing\n(a)');
      write('dylibs/b/h.scm', '(sibling)');
      write('queries/b/h.scm', '(query-only)');

      check(compose('a')).equals('(sibling)\n\n(a)');
    });

    test('answers null for a file the directory does not hold', () {
      check(
        composeQuery(p.join(archive.path, 'dylibs', 'none'), 'h.scm'),
      ).isNull();
    });

    test('composedFiles names every file the composition reads', () {
      write('dylibs/tsx/h.scm', '; inherits: typescript,jsx\n(t)');
      write('dylibs/typescript/h.scm', '; inherits: ecma\n(ts)');
      write('queries/ecma/h.scm', '(e)');
      write('queries/ecma/l.scm', '(unread)');
      write('queries/jsx/h.scm', '(j)');

      check(
        composedFiles(p.join(archive.path, 'dylibs', 'tsx'), 'h.scm'),
      ).unorderedEquals([
        for (final file in [
          'dylibs/tsx/h.scm',
          'dylibs/typescript/h.scm',
          'queries/ecma/h.scm',
          'queries/jsx/h.scm',
        ])
          p.join(archive.path, file),
      ]);
      check(
        composedFiles(p.join(archive.path, 'dylibs', 'none'), 'h.scm'),
      ).isEmpty();
    });
  });

  group("this repository's queries", () {
    test("php's folds and indents compose with php_only's", () {
      String compose(String file) =>
          composeQuery(p.join('queries', 'php'), file)!;

      check(compose('indents.scm'))
        ..contains('(array_creation_expression)')
        ..contains('@indent.begin');
      check(compose('folds.scm'))
        ..contains('(function_static_declaration)')
        ..contains('(compound_statement)')
        ..not((folds) => folds.contains('(if_statement)'));
    });
  });

  group('parseCorpus', () {
    test('reads names, inputs and languages', () {
      const corpus = '''
===
First
===

a b

---

(a)

===
Second
:language(tsx)
===
c
---
(c)
''';

      final examples = parseCorpus(corpus);

      check(examples.map((e) => e.name)).deepEquals(['First', 'Second']);
      check(examples.map((e) => e.input)).deepEquals(['\na b\n', 'c']);
      check(examples.map((e) => e.languages)).deepEquals([
        [''],
        ['tsx'],
      ]);
    });

    test('splits at the longest divider, so a shorter one is input', () {
      const corpus = '''
====
Rule
====
a
---
b
------
(x)
''';

      check(parseCorpus(corpus).single.input).equals('a\n---\nb');
    });

    test('counts only delimiters with the file\'s suffix', () {
      const corpus = '''
===|||
Heading
===|||
Title
===
---|||
(x)
''';

      check(parseCorpus(corpus).single.input).equals('Title\n===');
    });

    test('allows a blank line between a name and its attributes', () {
      const corpus = '''
===
Name

:language(xml)
===
<a/>
---
(x)
''';

      check(parseCorpus(corpus).single.languages).deepEquals(['xml']);
    });

    test('never reads a line of = inside an input as a header', () {
      const corpus = '''
===
Setext
===
Title
===

text
---
(x)
''';

      check(parseCorpus(corpus).single.input).equals('Title\n===\n\ntext');
    });
  });
}
