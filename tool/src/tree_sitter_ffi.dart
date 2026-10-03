/// The few tree-sitter runtime functions the release check calls, bound
/// through `dart:ffi` to a runtime library opened by path.
library;

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'query_predicates.dart';

/// `TSNode`, passed and returned by value.
final class TSNode extends Struct {
  @Array(4)
  external Array<Uint32> context;
  external Pointer<Void> id;
  external Pointer<Void> tree;
}

/// `TSTreeCursor`, returned by value.
final class TSTreeCursor extends Struct {
  external Pointer<Void> tree;
  external Pointer<Void> id;
  @Array(3)
  external Array<Uint32> context;
}

/// `TSPoint`.
final class TSPoint extends Struct {
  @Uint32()
  external int row;
  @Uint32()
  external int column;
}

/// `TSInputEdit`, passed by pointer.
final class TSInputEdit extends Struct {
  @Uint32()
  external int startByte;
  @Uint32()
  external int oldEndByte;
  @Uint32()
  external int newEndByte;
  external TSPoint startPoint;
  external TSPoint oldEndPoint;
  external TSPoint newEndPoint;
}

/// `TSQueryCapture`.
final class TSQueryCapture extends Struct {
  external TSNode node;
  @Uint32()
  external int index;
}

/// `TSQueryMatch`.
final class TSQueryMatch extends Struct {
  @Uint32()
  external int id;
  @Uint16()
  external int patternIndex;
  @Uint16()
  external int captureCount;
  external Pointer<TSQueryCapture> captures;
}

/// `TSQueryPredicateStep`.
final class TSQueryPredicateStep extends Struct {
  @Uint32()
  external int type;
  @Uint32()
  external int valueId;
}

/// `TSQueryPredicateStepTypeDone`, `…Capture` and `…String`.
const _stepDone = 0;
const _stepCapture = 1;

/// The names `TSQueryError` gives its values, by value.
const queryErrorNames = [
  'None',
  'Syntax',
  'NodeType',
  'Field',
  'Capture',
  'Structure',
  'Language',
];

/// Thrown when a query does not compile.
final class QueryException implements Exception {
  const QueryException(this.error, this.byteOffset);

  /// The `TSQueryError` name.
  final String error;

  /// The UTF-8 byte offset `ts_query_new` reported.
  final int byteOffset;

  @override
  String toString() => '$error error at byte $byteOffset';
}

/// One capture a query matched: its name, the byte range of its node, and
/// the [PatternPredicates.properties] of the pattern that made it.
typedef Capture = ({String name, int start, int end, String properties});

/// One match of a query: the index of the pattern that made it, which is
/// its place among the query's patterns, and the captures it made, in the
/// order the query cursor reports them.
typedef QueryMatch = ({int pattern, List<Capture> captures});

/// What [TreeSitterRuntime.parse] reads off one parse: the tree as an
/// S-expression, every node of it as [TreeSitterRuntime.dumpTree] lists
/// them, and the captures of each query, keyed by its name.
typedef Parsed = ({
  String tree,
  String nodes,
  Map<String, List<Capture>> captures,
});

/// A tree-sitter runtime library.
final class TreeSitterRuntime {
  /// Opens the runtime at [path] and binds the functions this file uses.
  TreeSitterRuntime.open(String path) : this._(DynamicLibrary.open(path));

  TreeSitterRuntime._(this.library)
    : _parserNew = library
          .lookupFunction<Pointer<Void> Function(), Pointer<Void> Function()>(
            'ts_parser_new',
          ),
      _parserDelete = library
          .lookupFunction<
            Void Function(Pointer<Void>),
            void Function(Pointer<Void>)
          >('ts_parser_delete'),
      _parserSetLanguage = library
          .lookupFunction<
            Bool Function(Pointer<Void>, Pointer<Void>),
            bool Function(Pointer<Void>, Pointer<Void>)
          >('ts_parser_set_language'),
      _parserParseString = library
          .lookupFunction<
            Pointer<Void> Function(
              Pointer<Void>,
              Pointer<Void>,
              Pointer<Utf8>,
              Uint32,
            ),
            Pointer<Void> Function(
              Pointer<Void>,
              Pointer<Void>,
              Pointer<Utf8>,
              int,
            )
          >('ts_parser_parse_string'),
      _treeDelete = library
          .lookupFunction<
            Void Function(Pointer<Void>),
            void Function(Pointer<Void>)
          >('ts_tree_delete'),
      _treeEdit = library
          .lookupFunction<
            Void Function(Pointer<Void>, Pointer<TSInputEdit>),
            void Function(Pointer<Void>, Pointer<TSInputEdit>)
          >('ts_tree_edit'),
      _treeRootNode = library
          .lookupFunction<
            TSNode Function(Pointer<Void>),
            TSNode Function(Pointer<Void>)
          >('ts_tree_root_node'),
      _nodeType = library
          .lookupFunction<
            Pointer<Utf8> Function(TSNode),
            Pointer<Utf8> Function(TSNode)
          >('ts_node_type'),
      _nodeIsNamed = library
          .lookupFunction<Bool Function(TSNode), bool Function(TSNode)>(
            'ts_node_is_named',
          ),
      _nodeIsMissing = library
          .lookupFunction<Bool Function(TSNode), bool Function(TSNode)>(
            'ts_node_is_missing',
          ),
      _nodeIsNull = library
          .lookupFunction<Bool Function(TSNode), bool Function(TSNode)>(
            'ts_node_is_null',
          ),
      _nodeParent = library
          .lookupFunction<TSNode Function(TSNode), TSNode Function(TSNode)>(
            'ts_node_parent',
          ),
      _cursorNew = library
          .lookupFunction<
            TSTreeCursor Function(TSNode),
            TSTreeCursor Function(TSNode)
          >('ts_tree_cursor_new'),
      _cursorDelete = library
          .lookupFunction<
            Void Function(Pointer<TSTreeCursor>),
            void Function(Pointer<TSTreeCursor>)
          >('ts_tree_cursor_delete'),
      _cursorNode = library
          .lookupFunction<
            TSNode Function(Pointer<TSTreeCursor>),
            TSNode Function(Pointer<TSTreeCursor>)
          >('ts_tree_cursor_current_node'),
      _cursorFieldName = library
          .lookupFunction<
            Pointer<Utf8> Function(Pointer<TSTreeCursor>),
            Pointer<Utf8> Function(Pointer<TSTreeCursor>)
          >('ts_tree_cursor_current_field_name'),
      _cursorFirstChild = library
          .lookupFunction<
            Bool Function(Pointer<TSTreeCursor>),
            bool Function(Pointer<TSTreeCursor>)
          >('ts_tree_cursor_goto_first_child'),
      _cursorNextSibling = library
          .lookupFunction<
            Bool Function(Pointer<TSTreeCursor>),
            bool Function(Pointer<TSTreeCursor>)
          >('ts_tree_cursor_goto_next_sibling'),
      _cursorParent = library
          .lookupFunction<
            Bool Function(Pointer<TSTreeCursor>),
            bool Function(Pointer<TSTreeCursor>)
          >('ts_tree_cursor_goto_parent'),
      _nodeString = library
          .lookupFunction<
            Pointer<Utf8> Function(TSNode),
            Pointer<Utf8> Function(TSNode)
          >('ts_node_string'),
      _nodeStartByte = library
          .lookupFunction<Uint32 Function(TSNode), int Function(TSNode)>(
            'ts_node_start_byte',
          ),
      _nodeEndByte = library
          .lookupFunction<Uint32 Function(TSNode), int Function(TSNode)>(
            'ts_node_end_byte',
          ),
      _languageAbiVersion = library
          .lookupFunction<
            Uint32 Function(Pointer<Void>),
            int Function(Pointer<Void>)
          >('ts_language_abi_version'),
      _queryNew = library
          .lookupFunction<
            Pointer<Void> Function(
              Pointer<Void>,
              Pointer<Utf8>,
              Uint32,
              Pointer<Uint32>,
              Pointer<Int32>,
            ),
            Pointer<Void> Function(
              Pointer<Void>,
              Pointer<Utf8>,
              int,
              Pointer<Uint32>,
              Pointer<Int32>,
            )
          >('ts_query_new'),
      _queryDelete = library
          .lookupFunction<
            Void Function(Pointer<Void>),
            void Function(Pointer<Void>)
          >('ts_query_delete'),
      _queryPatternCount = library
          .lookupFunction<
            Uint32 Function(Pointer<Void>),
            int Function(Pointer<Void>)
          >('ts_query_pattern_count'),
      _queryCaptureNameForId = library
          .lookupFunction<
            Pointer<Utf8> Function(Pointer<Void>, Uint32, Pointer<Uint32>),
            Pointer<Utf8> Function(Pointer<Void>, int, Pointer<Uint32>)
          >('ts_query_capture_name_for_id'),
      _queryCursorNew = library
          .lookupFunction<Pointer<Void> Function(), Pointer<Void> Function()>(
            'ts_query_cursor_new',
          ),
      _queryCursorDelete = library
          .lookupFunction<
            Void Function(Pointer<Void>),
            void Function(Pointer<Void>)
          >('ts_query_cursor_delete'),
      _queryCursorExec = library
          .lookupFunction<
            Void Function(Pointer<Void>, Pointer<Void>, TSNode),
            void Function(Pointer<Void>, Pointer<Void>, TSNode)
          >('ts_query_cursor_exec'),
      _queryCursorNextMatch = library
          .lookupFunction<
            Bool Function(Pointer<Void>, Pointer<TSQueryMatch>),
            bool Function(Pointer<Void>, Pointer<TSQueryMatch>)
          >('ts_query_cursor_next_match'),
      _queryPredicatesForPattern = library
          .lookupFunction<
            Pointer<TSQueryPredicateStep> Function(
              Pointer<Void>,
              Uint32,
              Pointer<Uint32>,
            ),
            Pointer<TSQueryPredicateStep> Function(
              Pointer<Void>,
              int,
              Pointer<Uint32>,
            )
          >('ts_query_predicates_for_pattern'),
      _queryStringValueForId = library
          .lookupFunction<
            Pointer<Utf8> Function(Pointer<Void>, Uint32, Pointer<Uint32>),
            Pointer<Utf8> Function(Pointer<Void>, int, Pointer<Uint32>)
          >('ts_query_string_value_for_id');

  /// The opened library.
  final DynamicLibrary library;

  final Pointer<Void> Function() _parserNew;
  final void Function(Pointer<Void>) _parserDelete;
  final bool Function(Pointer<Void>, Pointer<Void>) _parserSetLanguage;
  final Pointer<Void> Function(Pointer<Void>, Pointer<Void>, Pointer<Utf8>, int)
  _parserParseString;
  final void Function(Pointer<Void>) _treeDelete;
  final void Function(Pointer<Void>, Pointer<TSInputEdit>) _treeEdit;
  final TSNode Function(Pointer<Void>) _treeRootNode;
  final Pointer<Utf8> Function(TSNode) _nodeType;
  final bool Function(TSNode) _nodeIsNamed;
  final bool Function(TSNode) _nodeIsMissing;
  final bool Function(TSNode) _nodeIsNull;
  final TSNode Function(TSNode) _nodeParent;
  final TSTreeCursor Function(TSNode) _cursorNew;
  final void Function(Pointer<TSTreeCursor>) _cursorDelete;
  final TSNode Function(Pointer<TSTreeCursor>) _cursorNode;
  final Pointer<Utf8> Function(Pointer<TSTreeCursor>) _cursorFieldName;
  final bool Function(Pointer<TSTreeCursor>) _cursorFirstChild;
  final bool Function(Pointer<TSTreeCursor>) _cursorNextSibling;
  final bool Function(Pointer<TSTreeCursor>) _cursorParent;
  final Pointer<Utf8> Function(TSNode) _nodeString;
  final int Function(TSNode) _nodeStartByte;
  final int Function(TSNode) _nodeEndByte;
  final int Function(Pointer<Void>) _languageAbiVersion;
  final Pointer<Void> Function(
    Pointer<Void>,
    Pointer<Utf8>,
    int,
    Pointer<Uint32>,
    Pointer<Int32>,
  )
  _queryNew;
  final void Function(Pointer<Void>) _queryDelete;
  final int Function(Pointer<Void>) _queryPatternCount;
  final Pointer<Utf8> Function(Pointer<Void>, int, Pointer<Uint32>)
  _queryCaptureNameForId;
  final Pointer<Void> Function() _queryCursorNew;
  final void Function(Pointer<Void>) _queryCursorDelete;
  final void Function(Pointer<Void>, Pointer<Void>, TSNode) _queryCursorExec;
  final bool Function(Pointer<Void>, Pointer<TSQueryMatch>)
  _queryCursorNextMatch;
  final Pointer<TSQueryPredicateStep> Function(
    Pointer<Void>,
    int,
    Pointer<Uint32>,
  )
  _queryPredicatesForPattern;
  final Pointer<Utf8> Function(Pointer<Void>, int, Pointer<Uint32>)
  _queryStringValueForId;

  /// Whether the library exports [symbol], named without its leading
  /// underscore.
  bool exports(String symbol) => library.providesSymbol(symbol);

  /// `ts_language_abi_version` of [language].
  int abiVersion(Pointer<Void> language) => _languageAbiVersion(language);

  /// Whether `ts_parser_set_language` accepts [language].
  bool acceptsLanguage(Pointer<Void> language) {
    final parser = _parserNew();
    try {
      return _parserSetLanguage(parser, language);
    } finally {
      _parserDelete(parser);
    }
  }

  /// Compiles [source] for [language].
  ///
  /// Throws a [QueryException] when `ts_query_new` refuses it. The query
  /// holds native memory until [Query.delete].
  Query compile(Pointer<Void> language, String source) {
    final bytes = utf8.encode(source);
    final text = malloc<Uint8>(bytes.isEmpty ? 1 : bytes.length);
    final offset = malloc<Uint32>();
    final error = malloc<Int32>();
    try {
      text.asTypedList(bytes.length).setAll(0, bytes);
      final query = _queryNew(
        language,
        text.cast(),
        bytes.length,
        offset,
        error,
      );
      if (query == nullptr) {
        final kind = error.value;
        throw QueryException(
          kind >= 0 && kind < queryErrorNames.length
              ? queryErrorNames[kind]
              : 'error $kind',
          offset.value,
        );
      }
      return Query._(this, query, _queryPatternCount(query));
    } finally {
      malloc
        ..free(text)
        ..free(offset)
        ..free(error);
    }
  }

  /// Parses [text] with [language], returning the tree as an S-expression,
  /// every node of it (anonymous ones too) as [dumpTree] lists them, and
  /// every capture of each of [queries] over it, keyed by name: the
  /// captures of every match that satisfies its pattern's text and
  /// ancestry predicates, as [Query.predicates] reads them.
  ///
  /// Throws a [StateError] when the parser refuses the language or returns
  /// no tree.
  Parsed parse(
    Pointer<Void> language,
    String text,
    Map<String, Query> queries,
  ) => _parsed(
    language,
    text,
    (root, bytes) => (
      tree: _sexp(root),
      nodes: dumpTree(root),
      captures: {
        for (final MapEntry(key: name, value: query) in queries.entries)
          name: [
            for (final match in _matches(query, root, bytes)) ...match.captures,
          ],
      },
    ),
  );

  /// Parses [text] with [language], returning the tree as an S-expression
  /// and every match of [query] over it that satisfies its pattern's text
  /// and ancestry predicates, in the order the query cursor reports them.
  ///
  /// Throws a [StateError] when the parser refuses the language or returns
  /// no tree.
  ({String tree, List<QueryMatch> matches}) parseMatches(
    Pointer<Void> language,
    String text,
    Query query,
  ) => _parsed(
    language,
    text,
    (root, bytes) => (tree: _sexp(root), matches: _matches(query, root, bytes)),
  );

  /// Parses [text] with [language], then edits the tree to append
  /// [appended] and parses the longer text again with the edited tree, as
  /// an editor reparses after a keystroke, so the scanner's state is both
  /// serialized and restored from what it serialized.
  ///
  /// Throws a [StateError] when the parser refuses the language or returns
  /// no tree.
  void parseAndReparse(Pointer<Void> language, String text, String appended) {
    final parser = _parserNew();
    final bytes = utf8.encode('$text$appended');
    final length = utf8.encode(text).length;
    final input = malloc<Uint8>(bytes.isEmpty ? 1 : bytes.length);
    final edit = malloc<TSInputEdit>();
    var tree = nullptr.cast<Void>();
    var reparsed = nullptr.cast<Void>();
    try {
      if (!_parserSetLanguage(parser, language)) {
        throw StateError('ts_parser_set_language refused the language');
      }
      input.asTypedList(bytes.length).setAll(0, bytes);
      tree = _parserParseString(parser, nullptr, input.cast(), length);
      if (tree == nullptr) throw StateError('ts_parser_parse_string: NULL');
      final start = _pointAt(bytes, length);
      edit.ref
        ..startByte = length
        ..oldEndByte = length
        ..newEndByte = bytes.length;
      edit.ref.startPoint
        ..row = start.row
        ..column = start.column;
      edit.ref.oldEndPoint
        ..row = start.row
        ..column = start.column;
      final end = _pointAt(bytes, bytes.length);
      edit.ref.newEndPoint
        ..row = end.row
        ..column = end.column;
      _treeEdit(tree, edit);
      reparsed = _parserParseString(parser, tree, input.cast(), bytes.length);
      if (reparsed == nullptr) {
        throw StateError('ts_parser_parse_string: NULL on the reparse');
      }
    } finally {
      if (reparsed != nullptr) _treeDelete(reparsed);
      if (tree != nullptr) _treeDelete(tree);
      malloc
        ..free(edit)
        ..free(input);
      _parserDelete(parser);
    }
  }

  /// The row and the byte column at byte [offset] of [bytes].
  static ({int row, int column}) _pointAt(List<int> bytes, int offset) {
    var row = 0;
    var lineStart = 0;
    for (var index = 0; index < offset; index++) {
      if (bytes[index] == 0x0a) {
        row++;
        lineStart = index + 1;
      }
    }
    return (row: row, column: offset - lineStart);
  }

  /// What [read] makes of the root of [text] parsed with [language] and of
  /// [text]'s UTF-8 bytes, read before the tree is deleted.
  T _parsed<T>(
    Pointer<Void> language,
    String text,
    T Function(TSNode root, List<int> bytes) read,
  ) {
    final parser = _parserNew();
    final bytes = utf8.encode(text);
    final input = malloc<Uint8>(bytes.isEmpty ? 1 : bytes.length);
    Pointer<Void> tree = nullptr;
    try {
      if (!_parserSetLanguage(parser, language)) {
        throw StateError('ts_parser_set_language refused the language');
      }
      input.asTypedList(bytes.length).setAll(0, bytes);
      tree = _parserParseString(parser, nullptr, input.cast(), bytes.length);
      if (tree == nullptr) throw StateError('ts_parser_parse_string: NULL');
      return read(_treeRootNode(tree), bytes);
    } finally {
      if (tree != nullptr) _treeDelete(tree);
      malloc.free(input);
      _parserDelete(parser);
    }
  }

  String _sexp(TSNode root) {
    final string = _nodeString(root);
    try {
      return string.toDartString();
    } finally {
      malloc.free(string);
    }
  }

  /// Every node under [root], named or anonymous, one per line in
  /// document order: its depth, its field name, its type (an anonymous
  /// node's quoted, a missing node's marked) and its byte range.
  String dumpTree(TSNode root) {
    final cursor = malloc<TSTreeCursor>();
    cursor.ref = _cursorNew(root);
    final lines = StringBuffer();
    try {
      var depth = 0;
      while (true) {
        final node = _cursorNode(cursor);
        final field = _cursorFieldName(cursor);
        final type = _nodeType(node).toDartString();
        lines
          ..write('  ' * depth)
          ..write(field == nullptr ? '' : '${field.toDartString()}: ')
          ..write(_nodeIsNamed(node) ? type : jsonEncode(type))
          ..write(_nodeIsMissing(node) ? ' MISSING' : '')
          ..write(' [${_nodeStartByte(node)}, ${_nodeEndByte(node)})\n');
        if (_cursorFirstChild(cursor)) {
          depth++;
          continue;
        }
        while (!_cursorNextSibling(cursor)) {
          if (!_cursorParent(cursor)) return lines.toString();
          depth--;
        }
      }
    } finally {
      _cursorDelete(cursor);
      malloc.free(cursor);
    }
  }

  /// Every match of [query] under [root] that satisfies its pattern's text
  /// and ancestry predicates.
  List<QueryMatch> _matches(Query query, TSNode root, List<int> source) {
    final cursor = _queryCursorNew();
    final match = malloc<TSQueryMatch>();
    try {
      _queryCursorExec(cursor, query._pointer, root);
      final matches = <QueryMatch>[];
      while (_queryCursorNextMatch(cursor, match)) {
        final pattern = query.predicates[match.ref.patternIndex];
        final matched = [
          for (var i = 0; i < match.ref.captureCount; i++)
            (
              id: match.ref.captures[i].index,
              start: _nodeStartByte(match.ref.captures[i].node),
              end: _nodeEndByte(match.ref.captures[i].node),
            ),
        ];
        if (pattern.evaluated > 0) {
          final texts = <int, List<String>>{};
          for (final (:id, :start, :end) in matched) {
            (texts[id] ??= []).add(
              utf8.decode(source.sublist(start, end), allowMalformed: true),
            );
          }
          final ancestors = <int, List<List<String>>>{};
          if (pattern.readsAncestors) {
            for (var i = 0; i < match.ref.captureCount; i++) {
              final capture = match.ref.captures[i];
              (ancestors[capture.index] ??= []).add(_typesAbove(capture.node));
            }
          }
          if (!pattern.accepts(texts, ancestors: ancestors)) continue;
        }
        matches.add((
          pattern: match.ref.patternIndex,
          captures: [
            for (final (:id, :start, :end) in matched)
              (
                name: query.captureName(id),
                start: start,
                end: end,
                properties: pattern.properties,
              ),
          ],
        ));
      }
      return matches;
    } finally {
      malloc.free(match);
      _queryCursorDelete(cursor);
    }
  }

  /// The types of the nodes above [node], its parent first and the root
  /// last.
  List<String> _typesAbove(TSNode node) => [
    for (
      var above = _nodeParent(node);
      !_nodeIsNull(above);
      above = _nodeParent(above)
    )
      _nodeType(above).toDartString(),
  ];

  /// The predicates and directives of every pattern of [query], in order.
  List<PatternPredicates> _readPredicates(Query query) {
    final count = malloc<Uint32>();
    final length = malloc<Uint32>();
    try {
      return [
        for (var pattern = 0; pattern < query.patternCount; pattern++)
          PatternPredicates(() {
            final steps = _queryPredicatesForPattern(
              query._pointer,
              pattern,
              count,
            );
            final predicates = <QueryPredicate>[];
            var arguments = <PredicateArgument>[];
            String? name;
            for (var i = 0; i < count.value; i++) {
              final step = steps[i];
              if (step.type == _stepDone) {
                if (name != null || arguments.isNotEmpty) {
                  predicates.add((name: name ?? '', arguments: arguments));
                }
                name = null;
                arguments = [];
              } else if (step.type == _stepCapture) {
                arguments.add((
                  capture: step.valueId,
                  text: query.captureName(step.valueId),
                ));
              } else {
                final value = _queryStringValueForId(
                  query._pointer,
                  step.valueId,
                  length,
                ).toDartString(length: length.value);
                if (name == null && arguments.isEmpty) {
                  name = value;
                } else {
                  arguments.add((capture: null, text: value));
                }
              }
            }
            return predicates;
          }()),
      ];
    } finally {
      malloc
        ..free(count)
        ..free(length);
    }
  }
}

/// A compiled query.
final class Query {
  Query._(this._runtime, this._pointer, this.patternCount);

  final TreeSitterRuntime _runtime;
  final Pointer<Void> _pointer;
  final _captureNames = <int, String>{};

  /// `ts_query_pattern_count`.
  final int patternCount;

  /// What a comparison makes of each pattern's predicates and directives,
  /// by pattern index, read from `ts_query_predicates_for_pattern` once.
  late final List<PatternPredicates> predicates = _runtime._readPredicates(
    this,
  );

  /// The name of the capture [id].
  String captureName(int id) => _captureNames.putIfAbsent(id, () {
    final length = malloc<Uint32>();
    try {
      return _runtime
          ._queryCaptureNameForId(_pointer, id, length)
          .toDartString(length: length.value);
    } finally {
      malloc.free(length);
    }
  });

  /// Frees the query.
  void delete() => _runtime._queryDelete(_pointer);
}

/// Opens the grammar library at [path] and returns the language its
/// `tree_sitter_<symbol>` function answers.
Pointer<Void> openLanguage(String path, String symbol) {
  if (!File(path).existsSync()) throw StateError('no $path');
  final library = DynamicLibrary.open(path);
  final function = library
      .lookupFunction<Pointer<Void> Function(), Pointer<Void> Function()>(
        'tree_sitter_$symbol',
      );
  final language = function();
  if (language == nullptr) throw StateError('tree_sitter_$symbol: NULL');
  return language;
}
