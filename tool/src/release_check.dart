/// The parts of `tool/check_release.dart` that read files and text: query
/// composition, the patterns of a query's text, the outline a tags query's
/// matches make, the groups a tests query's matches put around each test,
/// the injections an injections query's matches make, the
/// captures a highlights query's matches draw, `api.h`'s function list,
/// the inputs of each grammar's test corpus, and what a crash test's run
/// says.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'tree_sitter_ffi.dart' show Capture, QueryMatch;

/// The `api.h` functions the runtime defines only when compiled with its
/// wasm feature, which the build does not enable.
const wasmOnlyFunctions = {
  'ts_wasm_store_new',
  'ts_wasm_store_load_language',
  'ts_wasm_store_language_count',
};

/// The function names `api.h`'s text [header] declares, sorted.
List<String> apiFunctions(String header) {
  final code = header
      .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
      .replaceAll(RegExp(r'//[^\n]*'), '');
  return {
    for (final match in RegExp(r'\b(ts_[a-z0-9_]+)\s*\(').allMatches(code))
      match.group(1)!,
  }.toList()..sort();
}

final _inherits = RegExp(r'^;\s*inherits:\s*(.+)$', multiLine: true);

/// Thrown when an `; inherits:` line names a language that holds no file
/// of the query type being composed.
final class QueryInheritanceException implements Exception {
  const QueryInheritanceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The one `; inherits:` name that may hold no file of the type naming
/// it, as (language, query file, inherited language).
///
/// tsx's `locals.scm` keeps nvim-treesitter's `; inherits: typescript,jsx`
/// line, the one tsx's folds, highlights and indents carry, and jsx has
/// no `locals.scm`, here or in nvim-treesitter. JSX's element and
/// attribute names are `identifier` and `property_identifier` nodes, which
/// tsx's own `locals.scm` captures as references, so jsx has no locals to
/// add.
const _inheritsNothing = {('tsx', 'locals.scm', 'jsx')};

/// The query [fileName] in [directory] with everything its first
/// `; inherits:` line names merged in ahead of it, or null when
/// [directory] holds no such file.
///
/// This is the rule the editor loads queries by: a named language is read
/// from the sibling directory of that name and, failing that, from the
/// `queries/` directory beside the one holding [directory]; an inherited
/// file is composed the same way; each file's own text follows what it
/// inherits, separated by a blank line.
///
/// Throws a [QueryInheritanceException] when a named language holds no
/// [fileName] in either place, which the editor would pass over without a
/// word; tsx's `locals.scm` naming `jsx` is the one name allowed to hold
/// none.
String? composeQuery(String directory, String fileName) =>
    _compose(directory, fileName, null);

/// The query files of a grammar's [directory], sorted.
List<String> queryFiles(String directory) => [
  for (final entity in Directory(directory).listSync())
    if (entity is File && entity.path.endsWith('.scm')) p.basename(entity.path),
]..sort();

/// One query file of a grammar, composed as [composeQuery] composes it.
typedef ComposedQuery = ({String directory, String fileName, String source});

/// What [composeArchiveQueries] found in an archive: how many query files
/// its grammars hold, those that composed, how many files its query-only
/// languages hold, and how many of those a composition read.
typedef ArchiveQueries = ({
  int fileCount,
  List<ComposedQuery> composed,
  int queryOnlyCount,
  int queryOnlyReadCount,
});

/// Composes every query file of each of [grammarDirectories] as
/// [composeQuery] does, and requires every file of a query-only language
/// in [archive]'s `queries/` to be read by one of those compositions.
///
/// Adds to [problems] each [QueryInheritanceException] a composition
/// throws, and each query-only file no composition reads: the editor reads
/// such a file only through an `; inherits:` line, so one nothing inherits
/// is never compiled or used. A file a composition reads before it throws
/// counts as read.
ArchiveQueries composeArchiveQueries(
  String archive,
  Iterable<String> grammarDirectories,
  List<String> problems,
) {
  var fileCount = 0;
  final composed = <ComposedQuery>[];
  final read = <String>{};
  for (final directory in grammarDirectories) {
    for (final fileName in queryFiles(directory)) {
      fileCount++;
      try {
        final source = _compose(directory, fileName, read)!;
        composed.add((
          directory: directory,
          fileName: fileName,
          source: source,
        ));
      } on QueryInheritanceException catch (error) {
        problems.add('$error');
      }
    }
  }
  final queryOnly = Directory(p.join(archive, 'queries'));
  final inheritable = [
    if (queryOnly.existsSync())
      for (final entity in queryOnly.listSync(recursive: true))
        if (entity is File && entity.path.endsWith('.scm'))
          p.normalize(entity.path),
  ]..sort();
  final unread = inheritable.where((file) => !read.contains(file)).toList();
  for (final file in unread) {
    problems.add(
      '${p.relative(file, from: archive)}: no grammar\'s '
      '${p.basename(file)} inherits it, so nothing reads it',
    );
  }
  return (
    fileCount: fileCount,
    composed: composed,
    queryOnlyCount: inheritable.length,
    queryOnlyReadCount: inheritable.length - unread.length,
  );
}

String? _compose(String directory, String fileName, Set<String>? read) {
  final file = File(p.join(directory, fileName));
  if (!file.existsSync()) return null;
  read?.add(p.normalize(file.path));
  final content = file.readAsStringSync();
  final match = _inherits.firstMatch(content);
  if (match == null) return content;
  final own = content.replaceFirst(match.group(0)!, '').trim();
  final languages = match
      .group(1)!
      .split(',')
      .map((name) => name.trim())
      .where((name) => name.isNotEmpty)
      .toList();
  if (languages.isEmpty) return own;
  final parent = p.dirname(directory);
  final queryOnly = p.join(p.dirname(parent), 'queries');
  final name = p.basename(directory);
  return [
    for (final language in languages)
      if (_compose(p.join(parent, language), fileName, read) ??
              _compose(p.join(queryOnly, language), fileName, read)
          case final inherited?)
        inherited
      else if (!_inheritsNothing.contains((name, fileName, language)))
        throw QueryInheritanceException(
          '$name/$fileName inherits $language, which holds no $fileName',
        ),
    own,
  ].join('\n\n');
}

/// The grammars whose composed `injections.scm` holds patterns that
/// capture `@injection.content` and name no language, which the editor
/// passes over without injecting anything.
///
/// Every other grammar's injection patterns each name a language, and
/// each grammar listed here holds at least one pattern that names none,
/// so the list is exactly the grammars left to repair.
const injectionsNamingNoLanguage = {
  'bash',
  'go',
  'html',
  'java',
  'kotlin',
  'make',
  'pascal',
  'python',
  'ruby',
  'sql',
  'xml',
  'yaml',
};

/// One top-level pattern of a query: the line it starts on and its text,
/// comments left out.
typedef QueryPattern = ({int line, String text});

/// The top-level patterns of the query [source], in order.
///
/// A pattern is a parenthesised or bracketed form, a string or a bare
/// token such as `_`, any of them after a field name such as `body:`,
/// with the captures and quantifiers that follow it; a `;` comment outside
/// a string is left out of its text. The count is the one `ts_query_new`
/// gives the same text.
List<QueryPattern> queryPatterns(String source) {
  final patterns = <QueryPattern>[];
  var line = 1;
  var counted = 0;
  var index = _skipSpace(source, 0);
  while (index < source.length) {
    line += '\n'.allMatches(source.substring(counted, index)).length;
    counted = index;
    final text = StringBuffer();
    index = _form(source, index, text);
    while (true) {
      final next = _skipSpace(source, index);
      final suffix = _suffix.matchAsPrefix(source, next);
      if (suffix == null) break;
      text.write(' ${suffix[0]}');
      index = suffix.end;
    }
    patterns.add((line: line, text: text.toString()));
    index = _skipSpace(source, index);
  }
  return patterns;
}

/// A capture or quantifier following a form.
final _suffix = RegExp(r'@[\w.\-]+|[*+?]');

/// A bare token at the top level of a query, such as `_`.
final _token = RegExp(r'[^\s()\[\]";]+');

/// The index of the first character at or after [index] in [source] that
/// is neither whitespace nor part of a `;` comment.
int _skipSpace(String source, int index) {
  while (index < source.length) {
    if (source[index] == ';') {
      final end = source.indexOf('\n', index);
      index = end < 0 ? source.length : end;
    } else if (source[index].trim().isEmpty) {
      index++;
    } else {
      break;
    }
  }
  return index;
}

/// Writes the form of [source] starting at [index] to [text], comments
/// left out, and returns the index just past it.
int _form(String source, int index, StringBuffer text) {
  var depth = 0;
  while (index < source.length) {
    final char = source[index];
    if (char == ';') {
      index = _skipSpace(source, index);
      text.write(' ');
    } else if (char == '"') {
      var end = index + 1;
      while (end < source.length && source[end] != '"') {
        end += source[end] == r'\' ? 2 : 1;
      }
      end = end < source.length ? end + 1 : source.length;
      text.write(source.substring(index, end));
      index = end;
      if (depth == 0) return index;
    } else if (depth == 0 && char != '(' && char != '[') {
      final end = _token.matchAsPrefix(source, index)?.end ?? index + 1;
      final token = source.substring(index, end);
      text.write(token);
      if (!token.endsWith(':')) return end;
      text.write(' ');
      index = _skipSpace(source, end);
    } else {
      text.write(char);
      index++;
      if (char == '(' || char == '[') depth++;
      if ((char == ')' || char == ']') && --depth == 0) return index;
    }
  }
  return index;
}

final _injectionContent = RegExp(r'@injection\.content(?![\w.\-])');
final _injectionLanguage = RegExp(
  r'@injection\.language(?![\w.\-])|'
  r'#set!\s+"?injection\.language(?![\w.\-])',
);

/// The line of every pattern of the injection query [source] that
/// captures `@injection.content` and names no language: it has neither an
/// `@injection.language` capture nor a `#set! injection.language`
/// directive, so the editor injects nothing where it matches.
List<int> injectionPatternsNamingNoLanguage(String source) => [
  for (final (:line, :text) in queryPatterns(source))
    if (_injectionContent.hasMatch(text) && !_injectionLanguage.hasMatch(text))
      line,
];

/// The line of every pattern of the injection query [source] that
/// captures no `@injection.content`, so the editor injects nothing where
/// it matches, whatever else it captures.
List<int> injectionPatternsCapturingNoContent(String source) => [
  for (final (:line, :text) in queryPatterns(source))
    if (!_injectionContent.hasMatch(text)) line,
];

/// One symbol a tags query defines: its kind, the capture name after
/// `definition.`; its name, the text of the match's `@name` capture; and
/// the byte range of the node its `@definition.<kind>` capture names.
typedef TagDefinition = ({String kind, String name, int start, int end});

/// The definitions among [matches], a tags query's captures one list per
/// match over the UTF-8 [text]: every match with a `@definition.<kind>`
/// capture, named by its `@name` capture or `<anonymous>` without one.
/// Matches with no definition capture, `@reference.<kind>` among them,
/// define nothing.
List<TagDefinition> tagDefinitions(
  List<List<Capture>> matches,
  List<int> text,
) => [
  for (final captures in matches)
    for (final definition in captures)
      if (definition.name.startsWith('definition.'))
        (
          kind: definition.name.substring('definition.'.length),
          name: switch (captures.where((c) => c.name == 'name').firstOrNull) {
            final name? => utf8.decode(
              text.sublist(name.start, name.end),
              allowMalformed: true,
            ),
            null => '<anonymous>',
          },
          start: definition.start,
          end: definition.end,
        ),
];

/// The outline of [definitions], one line per definition: its kind, a
/// space, and its name after the names of the definitions containing it,
/// joined by `.`, so `Namespace.Class.Method` spells a method's declaring
/// scope.
///
/// The lines follow the definitions ordered by start, the wider of two
/// that start together first. A definition contains another when its
/// range holds the other's and is not the same range, the rule the
/// editor nests its outline by. Two definitions over one range are both
/// listed, neither under the other; the editor keeps one of them.
List<String> outline(List<TagDefinition> definitions) {
  final sorted = [...definitions]
    ..sort(
      (a, b) => a.start != b.start ? a.start.compareTo(b.start) : b.end - a.end,
    );
  final open = <({TagDefinition definition, String path})>[];
  final lines = <String>[];
  for (final definition in sorted) {
    while (open.isNotEmpty && !_contains(open.last.definition, definition)) {
      open.removeLast();
    }
    final path = open.isEmpty
        ? definition.name
        : '${open.last.path}.${definition.name}';
    open.add((definition: definition, path: path));
    lines.add('${definition.kind} $path');
  }
  return lines;
}

/// Whether [outer]'s range holds [inner]'s and is not the same range.
bool _contains(TagDefinition outer, TagDefinition inner) =>
    outer.start <= inner.start &&
    inner.end <= outer.end &&
    (outer.start, outer.end) != (inner.start, inner.end);

/// What a tests query says encloses each test it finds, one line per
/// test as the editor reads it: the test's one-based line, a space, and
/// either the names of the groups around it, outermost first, as a JSON
/// array, or `withheld` and the reason the names cannot be read.
///
/// [matches] are a tests query's captures one list per match over the
/// UTF-8 [text]. A test is a node captured `@test`, and two captured at
/// one start are one test: a test registered per row of a table is a call
/// of what a call returns, and both start where the test does. A group is
/// a match captured `@group`, named by its `@group.name`; `@unnamed` and
/// `@table` matches are groups whose names the source does not write; each
/// encloses what its `@group.body` holds. An `@opaque` body that is no
/// group's `@group.body` is a function's, whose tests are registered under
/// whatever calls it.
///
/// A test is withheld, in this order, where another test starts on its
/// line (`sharedLine`), where the file binds a group function's name
/// (`rebinding`), and otherwise where anything but a named group encloses
/// it, for the innermost such level: `opaque`, `unnamed` or `table`. A
/// body holds the test where its range holds the test's, the same range
/// included, as an arrow function's body that is the test's own call does.
List<String> testStructureLines(List<List<Capture>> matches, List<int> text) {
  final tests = <int, Capture>{};
  final levels = <_TestLevel>[];
  final groupBodies = <(int, int)>{};
  final bodies = <(int, int)>{};
  var rebinding = false;
  for (final captures in matches) {
    Capture? named(String name) =>
        captures.where((c) => c.name == name).firstOrNull;
    for (final capture in captures) {
      switch (capture.name) {
        case 'test':
          tests.putIfAbsent(capture.start, () => capture);
        case 'opaque':
          bodies.add((capture.start, capture.end));
        case 'rebinding':
          rebinding = true;
      }
    }
    final body = named('group.body');
    if (body == null) continue;
    final written = named('group.name');
    final level = switch ((named('group'), written)) {
      (_?, final name?) => (
        start: body.start,
        end: body.end,
        name: utf8.decode(
          text.sublist(name.start, name.end),
          allowMalformed: true,
        ),
        withheld: null,
      ),
      _ when named('unnamed') != null => (
        start: body.start,
        end: body.end,
        name: null,
        withheld: 'unnamed',
      ),
      _ when named('table') != null => (
        start: body.start,
        end: body.end,
        name: null,
        withheld: 'table',
      ),
      _ => null,
    };
    if (level == null) continue;
    groupBodies.add((body.start, body.end));
    levels.add(level);
  }
  for (final (start, end) in bodies) {
    if (groupBodies.contains((start, end))) continue;
    levels.add((start: start, end: end, name: null, withheld: 'opaque'));
  }
  levels.sort(
    (a, b) => a.start != b.start ? a.start.compareTo(b.start) : b.end - a.end,
  );
  int lineOf(int offset) =>
      text.sublist(0, offset).where((byte) => byte == 0x0A).length + 1;
  final ordered = tests.values.toList()
    ..sort((a, b) => a.start.compareTo(b.start));
  final testsOnLine = <int, int>{};
  for (final test in ordered) {
    testsOnLine.update(lineOf(test.start), (n) => n + 1, ifAbsent: () => 1);
  }
  return [
    for (final test in ordered)
      '${lineOf(test.start)} '
          '${_enclosureOf(test, levels, sharesItsLine: testsOnLine[lineOf(test.start)]! > 1, rebinding: rebinding)}',
  ];
}

/// A level a tests query puts around what its body holds: a group named
/// [name], or a level whose name cannot be read, for the reason
/// [withheld].
typedef _TestLevel = ({int start, int end, String? name, String? withheld});

/// The names of the groups in [levels] around [test], JSON-encoded, or
/// `withheld` and why — see [testStructureLines].
String _enclosureOf(
  Capture test,
  List<_TestLevel> levels, {
  required bool sharesItsLine,
  required bool rebinding,
}) {
  if (sharesItsLine) return 'withheld sharedLine';
  if (rebinding) return 'withheld rebinding';
  final around = [
    for (final level in levels)
      if (level.start <= test.start && test.end <= level.end) level,
  ];
  for (final level in around.reversed) {
    if (level.withheld case final reason?) return 'withheld $reason';
  }
  return jsonEncode([for (final level in around) level.name]);
}

/// One injection a match of an injections query makes, as the editor
/// makes it: the language, the byte range of the whole node the match
/// captures as `@injection.content`, and whether the pattern sets
/// `injection.combined`.
typedef Injection = ({String language, bool combined, int start, int end});

final _setLanguage = RegExp(r'#set! "injection\.language" ("(?:[^"\\]|\\.)*")');
final _setCombined = RegExp(r'#set! "injection\.combined"(?= #|$)');

/// The injections among [matches], an injections query's captures one
/// list per match over the UTF-8 [text].
///
/// A match injects each node it captures as `@injection.content` in the
/// language its `@injection.language` capture's text names, or else its
/// pattern's `#set! injection.language` directive, which every capture
/// carries in its properties; a match that names no language, or an
/// empty one, injects nothing.
List<Injection> injections(List<List<Capture>> matches, List<int> text) => [
  for (final captures in matches)
    if (_injectionLanguageOf(captures, text) case final language?
        when language.isNotEmpty)
      for (final content in captures)
        if (content.name == 'injection.content')
          (
            language: language,
            combined: _setCombined.hasMatch(content.properties),
            start: content.start,
            end: content.end,
          ),
];

String? _injectionLanguageOf(List<Capture> captures, List<int> text) {
  if (captures.where((c) => c.name == 'injection.language').firstOrNull
      case final capture?) {
    return utf8.decode(
      text.sublist(capture.start, capture.end),
      allowMalformed: true,
    );
  }
  return switch (_setLanguage.firstMatch(
    captures.firstOrNull?.properties ?? '',
  )) {
    final set? => jsonDecode(set[1]!) as String,
    null => null,
  };
}

/// One line per injection of [found] over the UTF-8 [text]: its language,
/// ` combined` when its pattern combines it, a space and its text
/// JSON-encoded, ordered by start, the wider of two that start together
/// first, and two over one range by language, the uncombined first.
List<String> injectionLines(List<Injection> found, List<int> text) {
  int order(Injection a, Injection b) => switch ((
    a.start.compareTo(b.start),
    b.end.compareTo(a.end),
    a.language.compareTo(b.language),
  )) {
    (0, 0, 0) => (a.combined ? 1 : 0) - (b.combined ? 1 : 0),
    (0, 0, final language) => language,
    (0, final end, _) => end,
    (final start, _, _) => start,
  };
  final sorted = [...found]..sort(order);
  String textOf(int start, int end) =>
      utf8.decode(text.sublist(start, end), allowMalformed: true);
  return [
    for (final (:language, :combined, :start, :end) in sorted)
      '$language${combined ? ' combined' : ''} '
          '${jsonEncode(textOf(start, end))}',
  ];
}

/// The captures a highlights query writes that name no colour: `@none`,
/// `@spell` and `@nospell`, which a pattern sets beside a real capture of
/// the same node, and a capture whose name starts with `_`, which a
/// pattern writes for a predicate to read.
bool _drawsNothing(String capture) =>
    capture.startsWith('_') ||
    const {'none', 'spell', 'nospell'}.contains(capture);

/// One line per span a capture of [matches], a highlights query's matches
/// over the UTF-8 [text], is drawn over: the capture drawn, a space and the
/// span's text JSON-encoded, ordered by start, the wider of two that start
/// together first.
///
/// Of the captures over one span, the latest pattern's is drawn, the
/// convention the queries are written to: a language's own patterns
/// follow the ones its `; inherits:` line names, and a narrower pattern
/// follows the general one it refines, so each overrides the pattern
/// before it where both match. Of two captures one pattern makes over one
/// span, the later one is drawn. A capture that names no colour is left
/// out, so it neither draws nor overrides.
List<String> highlightLines(List<QueryMatch> matches, List<int> text) {
  final drawn = <(int, int), ({int pattern, String name})>{};
  for (final (:pattern, :captures) in matches) {
    for (final (:name, :start, :end, properties: _) in captures) {
      if (_drawsNothing(name)) continue;
      if (drawn[(start, end)] case final held? when held.pattern > pattern) {
        continue;
      }
      drawn[(start, end)] = (pattern: pattern, name: name);
    }
  }
  final spans = drawn.keys.toList()
    ..sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : b.$2 - a.$2);
  String textOf((int, int) span) =>
      utf8.decode(text.sublist(span.$1, span.$2), allowMalformed: true);
  return [
    for (final span in spans)
      '${drawn[span]!.name} ${jsonEncode(textOf(span))}',
  ];
}

/// One example of a tree-sitter test corpus.
typedef CorpusExample = ({String name, String input, List<String> languages});

/// The examples of the corpus file [text], read as the tree-sitter CLI
/// reads them.
///
/// A header is a line of three or more `=`, the example's name and any
/// attribute lines, and a closing `=` line; when the file's first `=` line
/// carries a suffix, only delimiters with that suffix count. A blank line
/// in a header is allowed only between the name and its attributes, so a
/// line of `=` inside an example's input is not read as a header. The
/// input runs from the header to the longest `-` divider of the example's
/// body (the last of equal length), less one trailing newline. Each
/// example's `languages` holds each `:language(<name>)` attribute, or a
/// single empty string for the corpus's default language.
List<CorpusExample> parseCorpus(String text) {
  final lines = _splitInclusive(text);
  String? firstSuffix;
  for (final line in lines) {
    final delimiter = _delimiter(line, '=');
    if (delimiter != null && delimiter.suffix.isNotEmpty) {
      firstSuffix = delimiter.suffix;
      break;
    }
  }
  final examples = <CorpusExample>[];
  ({String name, List<String> languages, int bodyStart})? pending;
  var index = 0;
  while (index < lines.length) {
    final header = _header(lines, firstSuffix, index);
    if (header == null) {
      index++;
      continue;
    }
    if (pending != null) {
      final example = _example(
        lines.sublist(pending.bodyStart, index),
        firstSuffix,
        pending,
      );
      if (example != null) examples.add(example);
    }
    pending = header;
    index = header.bodyStart;
  }
  if (pending != null) {
    final example = _example(
      lines.sublist(pending.bodyStart),
      firstSuffix,
      pending,
    );
    if (example != null) examples.add(example);
  }
  return examples;
}

List<String> _splitInclusive(String text) {
  final lines = <String>[];
  var start = 0;
  while (start < text.length) {
    final end = text.indexOf('\n', start);
    if (end < 0) {
      lines.add(text.substring(start));
      break;
    }
    lines.add(text.substring(start, end + 1));
    start = end + 1;
  }
  return lines;
}

({int length, String suffix})? _delimiter(String line, String char) {
  var length = 0;
  while (length < line.length && line[length] == char) {
    length++;
  }
  if (length < 3) return null;
  var suffix = line.substring(length);
  while (suffix.endsWith('\n') || suffix.endsWith('\r')) {
    suffix = suffix.substring(0, suffix.length - 1);
  }
  return (length: length, suffix: suffix);
}

bool _suffixMatches(String? first, String suffix) =>
    first == null ? suffix.isEmpty : suffix == first;

({String name, List<String> languages, int bodyStart})? _header(
  List<String> lines,
  String? firstSuffix,
  int start,
) {
  final opening = _delimiter(lines[start], '=');
  if (opening == null || !_suffixMatches(firstSuffix, opening.suffix)) {
    return null;
  }
  final name = StringBuffer();
  final languages = <String>[];
  var seenMarker = false;
  var index = start + 1;
  for (; index < lines.length; index++) {
    final closing = _delimiter(lines[index], '=');
    if (closing != null && _suffixMatches(firstSuffix, closing.suffix)) break;
    final trimmed = lines[index].trim();
    if (trimmed.isEmpty && !seenMarker && !_markerFollows(lines, index)) {
      return null;
    }
    final marker = trimmed.split('(').first;
    switch (marker) {
      case ':skip' || ':fail-fast' || ':error' || ':cst':
        seenMarker = true;
      case ':platform':
        if (trimmed.startsWith(':platform(') && trimmed.endsWith(')')) {
          seenMarker = true;
        }
      case ':language':
        if (trimmed.startsWith(':language(') && trimmed.endsWith(')')) {
          seenMarker = true;
          languages.add(
            trimmed.substring(':language('.length, trimmed.length - 1),
          );
        }
      default:
        if (!seenMarker) name.write(lines[index]);
    }
  }
  if (index >= lines.length) return null;
  return (
    name: name.toString().trim(),
    languages: languages.isEmpty ? [''] : languages,
    bodyStart: index + 1,
  );
}

/// Whether the first line after [index] that is not blank is an attribute
/// line, so the blank lines at [index] separate a name from its
/// attributes.
bool _markerFollows(List<String> lines, int index) {
  for (var next = index + 1; next < lines.length; next++) {
    final trimmed = lines[next].trim();
    if (trimmed.isNotEmpty) return trimmed.startsWith(':');
  }
  return false;
}

CorpusExample? _example(
  List<String> body,
  String? firstSuffix,
  ({String name, List<String> languages, int bodyStart}) header,
) {
  int? divider;
  var best = 0;
  for (final (index, line) in body.indexed) {
    final delimiter = _delimiter(line, '-');
    if (delimiter == null || !_suffixMatches(firstSuffix, delimiter.suffix)) {
      continue;
    }
    final total = delimiter.length + delimiter.suffix.length;
    if (total >= best) {
      divider = index;
      best = total;
    }
  }
  if (divider == null) return null;
  var input = body.sublist(0, divider).join();
  if (input.endsWith('\n')) input = input.substring(0, input.length - 1);
  if (input.endsWith('\r')) input = input.substring(0, input.length - 1);
  return (name: header.name, input: input, languages: header.languages);
}

/// How long a crash test's process may run before it fails as a hang.
const crashTestTimeout = Duration(seconds: 60);

/// The names of the signals a crash test's process can end by, by number.
const _signalNames = {
  4: 'SIGILL',
  5: 'SIGTRAP',
  6: 'SIGABRT',
  8: 'SIGFPE',
  9: 'SIGKILL',
  10: 'SIGBUS',
  11: 'SIGSEGV',
};

/// What is wrong with one run of a crash test, or null when its process
/// exited 0.
///
/// [exitCode] is the process's exit code as `dart:io` reports it, negative
/// for a process ended by a signal, or null when it ran past
/// [crashTestTimeout] and was killed. [stderr] is what it wrote there, of
/// which the first non-empty line is quoted.
String? crashTestProblem(int? exitCode, String stderr) {
  final said = const LineSplitter()
      .convert(stderr)
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .firstOrNull;
  final saying = said == null ? '' : ': $said';
  return switch (exitCode) {
    0 => null,
    null =>
      'the parse ran past ${crashTestTimeout.inSeconds} seconds and was '
          'killed',
    < 0 =>
      'the parse ended the process with '
          '${_signalNames[-exitCode] ?? 'signal ${-exitCode}'}$saying',
    _ => 'the parse exited $exitCode$saying',
  };
}
