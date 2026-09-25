import 'dart:convert';
import 'dart:io';

import 'package:checks/checks.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../tool/src/grammar_pins.dart';
import '../tool/src/release_check.dart';
import '../tool/src/tree_sitter_ffi.dart' show Capture;

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

    test('a sibling wins over queries/', () {
      write('dylibs/a/h.scm', '; inherits: b\n(a)');
      write('dylibs/b/h.scm', '(sibling)');
      write('queries/b/h.scm', '(query-only)');

      check(compose('a')).equals('(sibling)\n\n(a)');
    });

    test('refuses a named language that holds no such file', () {
      write('dylibs/a/h.scm', '; inherits: b, missing\n(a)');
      write('dylibs/b/h.scm', '(b)');
      write('queries/missing/other.scm', '(other)');

      check(() => compose('a'))
          .throws<QueryInheritanceException>()
          .has((error) => error.message, 'message')
          .equals('a/h.scm inherits missing, which holds no h.scm');
    });

    test('refuses a missing name in a file it inherits', () {
      write('dylibs/a/h.scm', '; inherits: b\n(a)');
      write('dylibs/b/h.scm', '; inherits: missing\n(b)');

      check(() => compose('a')).throws<QueryInheritanceException>();
    });

    test('allows only tsx locals.scm to name jsx, which holds none', () {
      write('dylibs/tsx/locals.scm', '; inherits: typescript,jsx\n(t)');
      write('dylibs/typescript/locals.scm', '(ts)');
      write('dylibs/tsx/h.scm', '; inherits: typescript,jsx\n(t)');
      write('dylibs/typescript/h.scm', '(ts)');
      write('dylibs/javascript/locals.scm', '; inherits: jsx\n(js)');
      write('queries/jsx/folds.scm', '(j)');

      check(
        composeQuery(p.join(archive.path, 'dylibs', 'tsx'), 'locals.scm'),
      ).equals('(ts)\n\n(t)');
      check(() => compose('tsx')).throws<QueryInheritanceException>();
      check(
        () => composeQuery(
          p.join(archive.path, 'dylibs', 'javascript'),
          'locals.scm',
        ),
      ).throws<QueryInheritanceException>();
    });

    test('answers null for a file the directory does not hold', () {
      check(
        composeQuery(p.join(archive.path, 'dylibs', 'none'), 'h.scm'),
      ).isNull();
    });
  });

  group('composeArchiveQueries', () {
    late Directory archive;
    late List<String> problems;

    setUp(() {
      archive = Directory.systemTemp.createTempSync('archive');
      problems = [];
    });
    tearDown(() => archive.deleteSync(recursive: true));

    void write(String relative, String text) =>
        File(p.join(archive.path, relative))
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(text);

    ArchiveQueries composeAll(List<String> grammars) => composeArchiveQueries(
      archive.path,
      [for (final name in grammars) p.join(archive.path, 'dylibs', name)],
      problems,
    );

    test('composes every file, each query-only file read', () {
      write('dylibs/tsx/h.scm', '; inherits: typescript,jsx\n(t)');
      write('dylibs/typescript/h.scm', '; inherits: ecma\n(ts)');
      write('dylibs/typescript/l.scm', '; inherits: ecma\n(tl)');
      write('queries/ecma/h.scm', '(e)');
      write('queries/ecma/l.scm', '(el)');
      write('queries/jsx/h.scm', '(j)');

      final queries = composeAll(['tsx', 'typescript']);

      check(problems).isEmpty();
      check(queries.fileCount).equals(3);
      check([
        for (final query in queries.composed)
          (p.basename(query.directory), query.fileName, query.source),
      ]).deepEquals([
        ('tsx', 'h.scm', '(e)\n\n(ts)\n\n(j)\n\n(t)'),
        ('typescript', 'h.scm', '(e)\n\n(ts)'),
        ('typescript', 'l.scm', '(el)\n\n(tl)'),
      ]);
      check(queries.queryOnlyCount).equals(3);
      check(queries.queryOnlyReadCount).equals(3);
    });

    test('lists a name that holds no file and composes the rest', () {
      write('dylibs/php/folds.scm', '; inherits: php_only\n(p)');
      write('dylibs/php/indents.scm', '; inherits: php_only\n(pi)');
      write('queries/php_only/folds.scm', '(o)');

      final queries = composeAll(['php']);

      check(problems).deepEquals([
        'php/indents.scm inherits php_only, which holds no indents.scm',
      ]);
      check(queries.fileCount).equals(2);
      check([
        for (final query in queries.composed) query.fileName,
      ]).deepEquals(['folds.scm']);
      check(queries.queryOnlyReadCount).equals(1);
    });

    test('lists a query-only file nothing inherits', () {
      write('dylibs/tsx/h.scm', '; inherits: typescript,jsx\n(t)');
      write('dylibs/typescript/h.scm', '; inherits: ecma\n(ts)');
      write('queries/ecma/h.scm', '(e)');
      write('queries/ecma/l.scm', '(unread)');
      write('queries/jsx/h.scm', '(j)');

      final queries = composeAll(['tsx']);

      check(problems).deepEquals([
        "queries/ecma/l.scm: no grammar's l.scm inherits it, so nothing "
            'reads it',
      ]);
      check(queries.queryOnlyCount).equals(3);
      check(queries.queryOnlyReadCount).equals(2);
    });

    test('counts what a composition read before a name holding nothing', () {
      write('dylibs/tsx/h.scm', '; inherits: typescript,missing\n(t)');
      write('dylibs/typescript/h.scm', '; inherits: ecma\n(ts)');
      write('queries/ecma/h.scm', '(e)');

      final queries = composeAll(['tsx']);

      check(
        problems,
      ).deepEquals(['tsx/h.scm inherits missing, which holds no h.scm']);
      check(queries.composed).isEmpty();
      check(queries.queryOnlyReadCount).equals(1);
    });
  });

  group('queryPatterns', () {
    test('reads each top-level form with its captures and quantifiers', () {
      const query = '''
; a comment (with a paren
((comment) @x
  (#match? @x "[(]") ; a trailing comment
  (#set! injection.language "c"))

[
  (a)
  (b)
] @y

body: (block) @fold

(a)+ @z
"keyword" @k
_ @any
''';

      final patterns = queryPatterns(query);

      check(
        patterns.map((pattern) => pattern.line),
      ).deepEquals([2, 6, 11, 13, 14, 15]);
      check(patterns.first.text)
        ..contains('(#match? @x "[(]")')
        ..not((text) => text.contains('trailing'));
      check(patterns.skip(1).map((pattern) => pattern.text)).deepEquals([
        '[\n  (a)\n  (b)\n] @y',
        'body: (block) @fold',
        '(a) + @z',
        '"keyword" @k',
        '_ @any',
      ]);
    });
  });

  group('injectionPatternsNamingNoLanguage', () {
    test('lists the lines of the patterns that inject naming none', () {
      const query = '''
((preproc_arg) @injection.content
  (#set! injection.language "c"))

((comment) @injection.content
  ; (#set! injection.language "doxygen")
  (#match? @injection.content "^/[*][*]"))

(raw_string_literal
  delimiter: (raw_string_delimiter) @injection.language
  (raw_string_content) @injection.content)

((description) @injection.content
  (#set! "injection.language" "html"))

((html_tag) @injection.content)

((glimmer) @glimmer)
''';

      check(injectionPatternsNamingNoLanguage(query)).deepEquals([4, 15]);
    });
  });

  group('injectionPatternsCapturingNoContent', () {
    test('lists the lines of the patterns with no content capture', () {
      const query = '''
((comment) @injection.content
  (#set! injection.language "comment"))

(call_expression
  function: ((identifier) @_name
             (#eq? @_name "hbs"))
  arguments: ((template_string) @glimmer
              (#offset! @glimmer 0 1 0 -1)))

((regex_pattern) @injection.content.inner
  (#set! injection.language "regex"))

(raw_string_literal
  delimiter: (raw_string_delimiter) @injection.language
  (raw_string_content) @injection.content)
''';

      check(injectionPatternsCapturingNoContent(query)).deepEquals([4, 10]);
    });
  });

  group("this repository's queries", () {
    test('every file composes, each name it inherits holding the file', () {
      for (final directory in Directory(
        'queries',
      ).listSync().whereType<Directory>()) {
        for (final file in directory.listSync().whereType<File>()) {
          if (!file.path.endsWith('.scm')) continue;
          check(
            because: file.path,
            () => composeQuery(directory.path, p.basename(file.path)),
          ).returnsNormally();
        }
      }
    });

    test('objc, cpp and tsx hold none of the patterns they inherit', () {
      List<String> patterns(String source) => [
        for (final pattern in queryPatterns(source))
          pattern.text.replaceAll(RegExp(r'\s+'), ' '),
      ];
      for (final file in [
        'objc/folds.scm',
        'objc/highlights.scm',
        'objc/indents.scm',
        'objc/injections.scm',
        'objc/locals.scm',
        'cpp/indents.scm',
        'cpp/locals.scm',
        'tsx/highlights.scm',
        'tsx/injections.scm',
        'tsx/locals.scm',
      ]) {
        final path = p.join('queries', file);
        final own = patterns(File(path).readAsStringSync());
        final composed = patterns(
          composeQuery(p.dirname(path), p.basename(path))!,
        );
        final inherited = composed.take(composed.length - own.length);

        check(because: file, inherited).isNotEmpty();
        check(
          because: file,
          inherited.toSet().intersection(own.toSet()),
        ).isEmpty();
      }
    });

    test(
      'only the grammars listed hold injection patterns naming no language',
      () {
        final queryOnly = {
          for (final entry in parseGrammars(
            File(p.join('tool', 'grammars.json')).readAsStringSync(),
          ))
            if (entry['queryOnly'] == true) entry['name'],
        };
        final namingNone = [
          for (final directory in Directory(
            'queries',
          ).listSync().whereType<Directory>())
            if (!queryOnly.contains(p.basename(directory.path)))
              if (composeQuery(directory.path, 'injections.scm')
                  case final source?
                  when injectionPatternsNamingNoLanguage(source).isNotEmpty)
                p.basename(directory.path),
        ]..sort();

        check(
          namingNone,
        ).deepEquals(injectionsNamingNoLanguage.toList()..sort());
      },
    );

    test('every injection pattern captures @injection.content', () {
      for (final directory in Directory(
        'queries',
      ).listSync().whereType<Directory>()) {
        if (composeQuery(directory.path, 'injections.scm') case final source?) {
          check(
            because: directory.path,
            injectionPatternsCapturingNoContent(source),
          ).isEmpty();
        }
      }
    });

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

  group('tagDefinitions', () {
    test('names each definition by its match, skipping references', () {
      const text = 'namespace Café { class A {} }';
      Capture capture(String name, int start, int end) =>
          (name: name, start: start, end: end, properties: '');

      final definitions = tagDefinitions([
        [capture('name', 10, 15), capture('definition.module', 0, 30)],
        [capture('name', 24, 25), capture('reference.class', 18, 27)],
        [capture('definition.class', 18, 27)],
      ], utf8.encode(text));

      check(definitions).deepEquals([
        (kind: 'module', name: 'Café', start: 0, end: 30),
        (kind: 'class', name: '<anonymous>', start: 18, end: 27),
      ]);
    });
  });

  group('outline', () {
    TagDefinition definition(String kind, String name, int start, int end) =>
        (kind: kind, name: name, start: start, end: end);

    test('spells each definition under the ones whose range holds it', () {
      check(
        outline([
          definition('method', 'Run', 20, 30),
          definition('class', 'Tests', 10, 40),
          definition('module', 'Company.Product', 0, 100),
          definition('class', 'Other', 50, 60),
          definition('module', 'Next', 100, 120),
          definition('class', 'Last', 105, 110),
        ]),
      ).deepEquals([
        'module Company.Product',
        'class Company.Product.Tests',
        'method Company.Product.Tests.Run',
        'class Company.Product.Other',
        'module Next',
        'class Next.Last',
      ]);
    });

    test('puts the wider of two that start together first', () {
      check(
        outline([
          definition('method', 'Inner', 0, 10),
          definition('module', 'Outer', 0, 50),
        ]),
      ).deepEquals(['module Outer', 'method Outer.Inner']);
    });

    test('nests neither of two over the same range', () {
      check(
        outline([
          definition('class', 'A', 0, 10),
          definition('interface', 'B', 0, 10),
        ]),
      ).deepEquals(['class A', 'interface B']);
    });
  });

  group('injections', () {
    const text = 'R"sql(select)sql" /* é */ #define A (1)';
    Capture capture(String name, int start, int end, [String set = '']) =>
        (name: name, start: start, end: end, properties: set);

    test('reads the language from a capture or a #set! directive', () {
      final found = injections([
        [
          capture('injection.language', 2, 5),
          capture('injection.content', 6, 12),
        ],
        [
          capture(
            'injection.content',
            18,
            26,
            '#set! "injection.language" "comment"',
          ),
        ],
        [
          capture(
            'injection.content',
            37,
            40,
            '#set! "injection.combined" #set! "injection.language" "c"',
          ),
        ],
        [capture('injection.content', 0, 17)],
        [capture('injection.language', 2, 5)],
        [
          capture('injection.language', 17, 17),
          capture('injection.content', 0, 17),
        ],
      ], utf8.encode(text));

      check(found).deepEquals([
        (language: 'sql', combined: false, start: 6, end: 12),
        (language: 'comment', combined: false, start: 18, end: 26),
        (language: 'c', combined: true, start: 37, end: 40),
      ]);
    });

    test('lines each by start, the wider first, with its text', () {
      final lines = injectionLines([
        (language: 'c', combined: true, start: 37, end: 40),
        (language: 'c', combined: false, start: 37, end: 40),
        (language: 'asm', combined: true, start: 37, end: 40),
        (language: 'sql', combined: false, start: 6, end: 12),
        (language: 'comment', combined: false, start: 18, end: 26),
        (language: 'html', combined: false, start: 0, end: 17),
      ], utf8.encode(text));

      check(lines).deepEquals([
        r'html "R\"sql(select)sql\""',
        'sql "select"',
        'comment "/* é */"',
        'asm combined "(1)"',
        'c "(1)"',
        'c combined "(1)"',
      ]);
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
