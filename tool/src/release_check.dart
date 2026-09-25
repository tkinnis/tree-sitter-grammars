/// The parts of `tool/check_release.dart` that read files and text: query
/// composition, `api.h`'s function list, and the inputs of each grammar's
/// test corpus.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

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

/// The query [fileName] in [directory] with everything its first
/// `; inherits:` line names merged in ahead of it, or null when
/// [directory] holds no such file.
///
/// This is the rule the editor loads queries by: a named language is read
/// from the sibling directory of that name and, failing that, from the
/// `queries/` directory beside the one holding [directory]; an inherited
/// file is composed the same way; each file's own text follows what it
/// inherits, separated by a blank line.
String? composeQuery(String directory, String fileName) =>
    _compose(directory, fileName, null);

/// Every file [composeQuery] reads to compose [fileName] in [directory]:
/// the file itself and each file it inherits, directly or not; empty when
/// [directory] holds no such file.
Set<String> composedFiles(String directory, String fileName) {
  final read = <String>{};
  _compose(directory, fileName, read);
  return read;
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
  return [
    for (final language in languages)
      if (_compose(p.join(parent, language), fileName, read) ??
              _compose(p.join(queryOnly, language), fileName, read)
          case final inherited?)
        inherited,
    own,
  ].join('\n\n');
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
