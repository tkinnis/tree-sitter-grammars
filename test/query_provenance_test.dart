import 'dart:convert';

import 'package:checks/checks.dart';
import 'package:test/test.dart';

import '../tool/src/query_provenance.dart';

const _commit = '0123456789abcdef0123456789abcdef01234567';

Map<String, Object?> _nvimEntry({bool changed = true}) => {
      'origin': 'nvim',
      'changed': changed,
      'upstream': {
        'repo': 'https://github.com/nvim-treesitter/nvim-treesitter',
        'commit': _commit,
        'path': 'queries/c/highlights.scm',
      },
    };

const _hereEntry = {'origin': 'here', 'changed': false, 'upstream': null};

void main() {
  test('a complete, well-formed file reads with no problems', () {
    final json = jsonEncode({
      'queries/c/highlights.scm': _nvimEntry(),
      'queries/c/tags.scm': _hereEntry,
    });

    final reading = readQueryProvenance(
      json,
      ['queries/c/highlights.scm', 'queries/c/tags.scm'],
    );

    check(reading.problems).isEmpty();
    check(reading.entries['queries/c/highlights.scm'])
        .isNotNull()
        .has((entry) => entry.origin, 'origin')
        .equals(QueryOrigin.nvim);
  });

  test('a query file with no entry is reported', () {
    final json = jsonEncode({'queries/c/highlights.scm': _nvimEntry()});

    final reading = readQueryProvenance(
      json,
      ['queries/c/highlights.scm', 'queries/c/tags.scm'],
    );

    check(reading.problems).deepEquals(['queries/c/tags.scm: no entry']);
  });

  test('an entry naming no query file is reported', () {
    final json = jsonEncode({
      'queries/c/highlights.scm': _nvimEntry(),
      'queries/c/gone.scm': _hereEntry,
    });

    final reading = readQueryProvenance(json, ['queries/c/highlights.scm']);

    check(reading.problems)
        .deepEquals(['queries/c/gone.scm: entry names no query file']);
  });

  test('a duplicated key is reported although the decoder keeps one', () {
    final entry = jsonEncode(_hereEntry);
    final json = '{"queries/c/tags.scm": $entry, "queries/c/tags.scm": $entry}';

    final reading = readQueryProvenance(json, ['queries/c/tags.scm']);

    check(reading.problems).deepEquals(['queries/c/tags.scm: 2 entries']);
  });

  test('here with an upstream, or changed, is refused', () {
    final json = jsonEncode({
      'queries/c/tags.scm': {..._nvimEntry(), 'origin': 'here'},
    });

    final reading = readQueryProvenance(json, ['queries/c/tags.scm']);

    check(reading.problems).deepEquals([
      'queries/c/tags.scm: origin here takes no upstream and is never changed',
    ]);
  });

  test('an upstream origin with no upstream is refused', () {
    final json = jsonEncode({
      'queries/c/tags.scm': {'origin': 'grammar', 'changed': false},
    });

    final reading = readQueryProvenance(json, ['queries/c/tags.scm']);

    check(reading.problems)
        .deepEquals(['queries/c/tags.scm: origin grammar needs an upstream']);
  });

  test('an abbreviated commit, an unknown origin and a stray field fail', () {
    final entry = _nvimEntry();
    (entry['upstream']! as Map<String, Object?>)['commit'] = '0123abc';
    final json = jsonEncode({
      'queries/c/highlights.scm': entry,
      'queries/c/tags.scm': {..._hereEntry, 'origin': 'zed', 'note': 'x'},
    });

    final reading = readQueryProvenance(
      json,
      ['queries/c/highlights.scm', 'queries/c/tags.scm'],
    );

    check(reading.problems).unorderedEquals([
      'queries/c/highlights.scm: upstream.commit must be 40 lowercase hex '
          'digits',
      'queries/c/tags.scm: unknown field "note"',
      'queries/c/tags.scm: origin must be one of nvim, grammar, both, here',
    ]);
  });

  test('nvimUpstream is accepted only on origin both', () {
    final upstream = _nvimEntry()['upstream'];
    final json = jsonEncode({
      'queries/c/highlights.scm': {..._nvimEntry(), 'nvimUpstream': upstream},
      'queries/c/tags.scm': {
        ..._nvimEntry(),
        'origin': 'both',
        'nvimUpstream': upstream,
      },
    });

    final reading = readQueryProvenance(
      json,
      ['queries/c/highlights.scm', 'queries/c/tags.scm'],
    );

    check(reading.problems).deepEquals([
      'queries/c/highlights.scm: nvimUpstream belongs only to origin both',
    ]);
  });
}
