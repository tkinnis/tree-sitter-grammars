import 'package:checks/checks.dart';
import 'package:test/test.dart';

import '../tool/src/query_predicates.dart';

PredicateArgument _capture(int id, String name) => (capture: id, text: name);

PredicateArgument _string(String text) => (capture: null, text: text);

QueryPredicate _predicate(String name, List<PredicateArgument> arguments) =>
    (name: name, arguments: arguments);

PatternPredicates _one(String name, List<PredicateArgument> arguments) =>
    PatternPredicates([_predicate(name, arguments)]);

void main() {
  group('the eq? family', () {
    final eq = _one('eq?', [_capture(0, 'x'), _string('self')]);
    final notEq = _one('not-eq?', [_capture(0, 'x'), _string('self')]);
    final anyEq = _one('any-eq?', [_capture(0, 'x'), _string('self')]);
    final anyNotEq = _one('any-not-eq?', [_capture(0, 'x'), _string('self')]);

    test('compares a capture with a string', () {
      check(
        eq.accepts({
          0: ['self'],
        }),
      ).isTrue();
      check(
        eq.accepts({
          0: ['this'],
        }),
      ).isFalse();
      check(
        notEq.accepts({
          0: ['self'],
        }),
      ).isFalse();
      check(
        notEq.accepts({
          0: ['this'],
        }),
      ).isTrue();
    });

    test('needs every node of a quantified capture, or one with any-', () {
      check(
        eq.accepts({
          0: ['self', 'this'],
        }),
      ).isFalse();
      check(
        anyEq.accepts({
          0: ['this', 'self'],
        }),
      ).isTrue();
      check(
        anyEq.accepts({
          0: ['this', 'that'],
        }),
      ).isFalse();
      check(
        anyNotEq.accepts({
          0: ['self', 'this'],
        }),
      ).isTrue();
      check(
        anyNotEq.accepts({
          0: ['self', 'self'],
        }),
      ).isFalse();
    });

    test('holds for a capture the match did not make', () {
      check(eq.accepts({})).isTrue();
      check(
        notEq.accepts({
          1: ['self'],
        }),
      ).isTrue();
    });

    test('compares two captures pairwise', () {
      final same = _one('eq?', [_capture(0, 'key'), _capture(1, 'value')]);

      check(
        same.accepts({
          0: ['a'],
          1: ['a'],
        }),
      ).isTrue();
      check(
        same.accepts({
          0: ['a'],
          1: ['b'],
        }),
      ).isFalse();
      check(
        same.accepts({
          0: ['a', 'b'],
          1: ['a'],
        }),
      ).isFalse();
    });
  });

  group('the match? family', () {
    test('searches the text, anchored only where the pattern is', () {
      final constant = _one('match?', [
        _capture(0, 'constant'),
        _string(r'^[A-Z][A-Z\d_]*$'),
      ]);

      check(
        constant.accepts({
          0: ['MAX_SIZE'],
        }),
      ).isTrue();
      check(
        constant.accepts({
          0: ['MaxSize'],
        }),
      ).isFalse();
      check(
        _one('match?', [_capture(0, 'x'), _string('b')]).accepts({
          0: ['abc'],
        }),
      ).isTrue();
    });

    test('negates with not- and relaxes with any-', () {
      final notMatch = _one('not-match?', [_capture(0, 'x'), _string('^_')]);
      final anyMatch = _one('any-match?', [_capture(0, 'x'), _string('^_')]);

      check(
        notMatch.accepts({
          0: ['_a'],
        }),
      ).isFalse();
      check(
        notMatch.accepts({
          0: ['a'],
        }),
      ).isTrue();
      check(
        anyMatch.accepts({
          0: ['a', '_b'],
        }),
      ).isTrue();
      check(
        anyMatch.accepts({
          0: ['a', 'b'],
        }),
      ).isFalse();
    });

    test('carries a regular expression Dart refuses as text', () {
      final refused = _one('match?', [_capture(0, 'x'), _string('(?i)abc')]);

      check(refused.evaluated).equals(0);
      check(refused.refusedRegexes).deepEquals(['(?i)abc']);
      check(refused.properties).equals('#match? @x "(?i)abc"');
      check(
        refused.accepts({
          0: ['xyz'],
        }),
      ).isTrue();
    });
  });

  test('any-of? and not-any-of? need every node', () {
    final anyOf = _one('any-of?', [
      _capture(0, 'x'),
      _string('module'),
      _string('window'),
    ]);
    final notAnyOf = _one('not-any-of?', [_capture(0, 'x'), _string('module')]);

    check(
      anyOf.accepts({
        0: ['window'],
      }),
    ).isTrue();
    check(
      anyOf.accepts({
        0: ['window', 'other'],
      }),
    ).isFalse();
    check(
      notAnyOf.accepts({
        0: ['other'],
      }),
    ).isTrue();
    check(
      notAnyOf.accepts({
        0: ['module'],
      }),
    ).isFalse();
  });

  test('carries every directive and unknown predicate as text', () {
    final pattern = PatternPredicates([
      _predicate('set!', [_string('injection.language'), _string('comment')]),
      _predicate('eq?', [_capture(0, 'x'), _string('self')]),
      _predicate('is-not?', [_string('local')]),
      _predicate('offset!', [
        _capture(1, 'content'),
        _string('0'),
        _string('1'),
      ]),
    ]);

    check(pattern.evaluated).equals(1);
    check(pattern.properties).equals(
      '#set! "injection.language" "comment" #is-not? "local" '
      '#offset! @content "0" "1"',
    );
  });

  test('carries a text predicate with malformed arguments as text', () {
    final malformed = PatternPredicates([
      _predicate('eq?', [_string('self'), _capture(0, 'x')]),
      _predicate('match?', [_capture(0, 'x')]),
      _predicate('any-of?', [_capture(0, 'x'), _capture(1, 'y')]),
    ]);

    check(malformed.evaluated).equals(0);
    check(
      malformed.properties,
    ).equals('#eq? "self" @x #match? @x #any-of? @x @y');
  });
}
