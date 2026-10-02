/// The predicates and directives of a query pattern, as a comparison of two
/// archives reads them: the text and ancestry predicates are evaluated on
/// each match, and everything else is carried as text by every capture the
/// pattern makes.
library;

import 'dart:convert';

/// One argument of a predicate: a capture, with its id in [capture] and its
/// name in [text], or a string, in [text].
typedef PredicateArgument = ({int? capture, String text});

/// One predicate or directive of a pattern, as
/// `ts_query_predicates_for_pattern` lists it: its name without the `#`,
/// and its arguments.
typedef QueryPredicate = ({String name, List<PredicateArgument> arguments});

/// The text predicates [PatternPredicates] evaluates: tree-sitter's
/// documented `eq?`, `match?` and `any-of?` families.
const evaluatedPredicates = {
  'eq?',
  'not-eq?',
  'any-eq?',
  'any-not-eq?',
  'match?',
  'not-match?',
  'any-match?',
  'any-not-match?',
  'any-of?',
  'not-any-of?',
};

/// The ancestry predicates [PatternPredicates] evaluates: nvim-treesitter's
/// `has-ancestor?` and `has-parent?`, which name the types of node a
/// capture has to sit beneath, and their `not-` forms.
const ancestryPredicates = {
  'has-ancestor?',
  'not-has-ancestor?',
  'has-parent?',
  'not-has-parent?',
};

/// What a comparison makes of one pattern's predicates and directives.
///
/// A text predicate of [evaluatedPredicates] with well-formed arguments is
/// evaluated on each match, as tree-sitter documents it: `eq?`, `not-eq?`,
/// `match?`, `not-match?` and `not-any-of?` and `any-of?` hold when every
/// node of a quantified capture satisfies them, and the `any-` forms of
/// `eq?` and `match?` when one does; `eq?` between two captures compares
/// their nodes pairwise. A predicate naming a capture the match did not
/// make holds. A `match?` regular expression is read as a Dart one.
///
/// An ancestry predicate of [ancestryPredicates], a capture followed by
/// node types, is evaluated as the editor reads it: `has-ancestor?` holds
/// when a node of one of the types sits anywhere above a node of the
/// capture, `has-parent?` when one is its parent, and each `not-` form
/// where the plain form does not hold. A capture holding several nodes
/// holds where any of them does, and a capture the match did not make
/// holds under either form.
///
/// Every other predicate and directive, a `#set!` above all, and any text
/// or ancestry predicate that cannot be evaluated (malformed arguments, or
/// a regular expression Dart refuses) is written into [properties], which
/// every capture of the pattern carries, so a change to it is a change to
/// the pattern's results.
final class PatternPredicates {
  /// Reads [predicates] of one pattern.
  factory PatternPredicates(List<QueryPredicate> predicates) {
    final tests = <_TextTest>[];
    final ancestry = <_AncestryTest>[];
    final rest = <String>[];
    final refused = <String>[];
    for (final predicate in predicates) {
      final (test, regex) = _TextTest.read(predicate);
      if (test != null) {
        tests.add(test);
        continue;
      }
      if (_AncestryTest.read(predicate) case final ancestor?) {
        ancestry.add(ancestor);
        continue;
      }
      if (regex != null) refused.add(regex);
      rest.add(_render(predicate));
    }
    return PatternPredicates._(tests, ancestry, rest.join(' '), refused);
  }

  PatternPredicates._(
    this._tests,
    this._ancestry,
    this.properties,
    this.refusedRegexes,
  );

  final List<_TextTest> _tests;
  final List<_AncestryTest> _ancestry;

  /// The predicates and directives this pattern carries unevaluated, as
  /// text: each `#<name>` followed by its arguments, a capture as
  /// `@<name>` and a string JSON-encoded; empty when there are none.
  final String properties;

  /// The `match?` regular expressions Dart refused, which [properties]
  /// carries as text.
  final List<String> refusedRegexes;

  /// The number of text and ancestry predicates evaluated on each match.
  int get evaluated => _tests.length + _ancestry.length;

  /// Whether a match has to be given the types above its captures' nodes,
  /// which only an ancestry predicate reads.
  bool get readsAncestors => _ancestry.isNotEmpty;

  /// Whether a match whose captures have [texts], by capture id in match
  /// order, and the node types above them in [ancestors], by capture id in
  /// match order and nearest first, satisfies every evaluated predicate.
  bool accepts(
    Map<int, List<String>> texts, {
    Map<int, List<List<String>>> ancestors = const {},
  }) =>
      _tests.every((test) => test.holds(texts)) &&
      _ancestry.every((test) => test.holds(ancestors));
}

String _render(QueryPredicate predicate) => [
  '#${predicate.name}',
  for (final argument in predicate.arguments)
    argument.capture == null ? jsonEncode(argument.text) : '@${argument.text}',
].join(' ');

/// One evaluated text predicate.
final class _TextTest {
  _TextTest._(
    this._capture,
    this._positive,
    this._every, {
    int? otherCapture,
    Set<String>? values,
    RegExp? pattern,
  }) : _otherCapture = otherCapture,
       _values = values,
       _pattern = pattern;

  /// The test [predicate] makes, or null with the regular expression Dart
  /// refused, if that is why it cannot be evaluated.
  static (_TextTest?, String?) read(QueryPredicate predicate) {
    final QueryPredicate(:name, :arguments) = predicate;
    if (!evaluatedPredicates.contains(name) ||
        arguments.length < 2 ||
        arguments.first.capture == null) {
      return (null, null);
    }
    final capture = arguments.first.capture!;
    final family = name.replaceFirst('any-', '').replaceFirst('not-', '');
    final positive = !name.contains('not-');
    final every = !name.startsWith('any-') || family == 'of?';
    switch (family) {
      case 'of?':
        if (arguments.skip(1).any((a) => a.capture != null)) {
          return (null, null);
        }
        return (
          _TextTest._(
            capture,
            positive,
            true,
            values: {for (final a in arguments.skip(1)) a.text},
          ),
          null,
        );
      case 'eq?' when arguments.length == 2:
        final other = arguments[1];
        return (
          other.capture == null
              ? _TextTest._(capture, positive, every, values: {other.text})
              : _TextTest._(
                  capture,
                  positive,
                  every,
                  otherCapture: other.capture,
                ),
          null,
        );
      case 'match?' when arguments.length == 2 && arguments[1].capture == null:
        final source = arguments[1].text;
        try {
          return (
            _TextTest._(capture, positive, every, pattern: RegExp(source)),
            null,
          );
        } on FormatException {
          return (null, source);
        }
      default:
        return (null, null);
    }
  }

  final int _capture;
  final bool _positive;

  /// Whether every node must satisfy the test, rather than one.
  final bool _every;
  final int? _otherCapture;
  final Set<String>? _values;
  final RegExp? _pattern;

  bool holds(Map<int, List<String>> texts) {
    final nodes = texts[_capture] ?? const <String>[];
    if (_otherCapture case final other?) {
      final others = texts[other] ?? const <String>[];
      if (nodes.isEmpty || others.isEmpty) return true;
      final pairs = nodes.length < others.length ? nodes.length : others.length;
      final results = [
        for (var i = 0; i < pairs; i++) (nodes[i] == others[i]) == _positive,
      ];
      return _every
          ? nodes.length == others.length && results.every((r) => r)
          : results.any((r) => r);
    }
    if (nodes.isEmpty) return true;
    bool satisfies(String text) =>
        (_pattern?.hasMatch(text) ?? _values!.contains(text)) == _positive;
    return _every ? nodes.every(satisfies) : nodes.any(satisfies);
  }
}

/// One evaluated ancestry predicate.
final class _AncestryTest {
  _AncestryTest._(
    this._capture,
    this._types, {
    required bool negated,
    required bool parentOnly,
  }) : _negated = negated,
       _parentOnly = parentOnly;

  /// The test [predicate] makes, or null when it is not an ancestry
  /// predicate whose first argument is a capture and whose others are
  /// node types.
  static _AncestryTest? read(QueryPredicate predicate) {
    final QueryPredicate(:name, :arguments) = predicate;
    if (!ancestryPredicates.contains(name) ||
        arguments.length < 2 ||
        arguments.first.capture == null ||
        arguments.skip(1).any((a) => a.capture != null)) {
      return null;
    }
    return _AncestryTest._(
      arguments.first.capture!,
      {for (final argument in arguments.skip(1)) argument.text},
      negated: name.startsWith('not-'),
      parentOnly: name.endsWith('has-parent?'),
    );
  }

  final int _capture;
  final Set<String> _types;
  final bool _negated;
  final bool _parentOnly;

  bool holds(Map<int, List<List<String>>> ancestors) {
    final nodes = ancestors[_capture] ?? const <List<String>>[];
    if (nodes.isEmpty) return true;
    final named = nodes.any(
      (above) => _parentOnly
          ? above.isNotEmpty && _types.contains(above.first)
          : above.any(_types.contains),
    );
    return named != _negated;
  }
}
