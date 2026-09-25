import 'package:checks/checks.dart';
import 'package:test/test.dart';

import '../tool/src/query_headers.dart';
import '../tool/src/query_provenance.dart';

const _nvimCommit = '692b051b09935653befdb8f7ba8afdb640adf17b';
const _grammarCommit = '0123456789abcdef0123456789abcdef01234567';
const _grammarUrl = 'https://github.com/example/tree-sitter-example';

const _nvimFile = UpstreamFile(
  repo: nvimTreesitterUrl,
  commit: _nvimCommit,
  path: 'runtime/queries/c/highlights.scm',
);

String _license(String repository) =>
    repository == _grammarUrl ? 'MIT' : throw ArgumentError(repository);

void main() {
  test('an nvim file names its source and whether it changed', () {
    final header = queryHeader(
      'queries/c/highlights.scm',
      const QueryProvenance(
        origin: QueryOrigin.nvim,
        changed: true,
        upstream: _nvimFile,
      ),
      _license,
    );

    check(header).deepEquals([
      '; Derived from nvim-treesitter $nvimTreesitterUrl, '
          'runtime/queries/c/highlights.scm @ $_nvimCommit, Apache-2.0.',
      '; Modified in tree-sitter-grammars.',
    ]);
  });

  test('a file taken from a grammar names nvim-treesitter and the grammar', () {
    final header = queryHeader(
      'queries/example/highlights.scm',
      const QueryProvenance(
        origin: QueryOrigin.both,
        changed: false,
        upstream: UpstreamFile(
          repo: _grammarUrl,
          commit: _grammarCommit,
          path: 'queries/highlights.scm',
        ),
        nvimUpstream: _nvimFile,
      ),
      _license,
    );

    check(header).deepEquals([
      '; Derived from nvim-treesitter $nvimTreesitterUrl, '
          'runtime/queries/c/highlights.scm @ $_nvimCommit, Apache-2.0.',
      '; Taken from $_grammarUrl, queries/highlights.scm @ $_grammarCommit, '
          'MIT.',
      '; Unchanged.',
    ]);
  });

  test('grammar and here files carry no header', () {
    for (final provenance in const [
      QueryProvenance(origin: QueryOrigin.here, changed: false),
      QueryProvenance(
        origin: QueryOrigin.grammar,
        changed: true,
        upstream: UpstreamFile(
          repo: _grammarUrl,
          commit: _grammarCommit,
          path: 'queries/highlights.scm',
        ),
      ),
    ]) {
      check(queryHeader('queries/x.scm', provenance, _license)).isEmpty();
    }
  });

  test('a "both" entry naming no nvim-treesitter file is refused', () {
    check(
      () => queryHeader(
        'queries/example/highlights.scm',
        const QueryProvenance(
          origin: QueryOrigin.both,
          changed: true,
          upstream: UpstreamFile(
            repo: _grammarUrl,
            commit: _grammarCommit,
            path: 'queries/highlights.scm',
          ),
        ),
        _license,
      ),
    ).throws<QueryHeaderException>();
  });

  group('withQueryHeader', () {
    const header = ['; Derived from nvim-treesitter x', '; Unchanged.'];
    const body = '; inherits: c\n\n(identifier) @variable\n';

    test('puts the header and a blank line before the body', () {
      check(
        withQueryHeader(body, header),
      ).equals('${header.join('\n')}\n\n$body');
    });

    test('replaces a header already there instead of stacking another', () {
      final once = withQueryHeader(body, header);
      const other = [
        '; Derived from nvim-treesitter y',
        '; Taken from z',
        '; Modified in tree-sitter-grammars.',
      ];
      check(withQueryHeader(withQueryHeader(once, other), header)).equals(once);
      check(withQueryHeader(once, const [])).equals(body);
    });
  });

  group('unchangedNvimSource', () {
    const body = '(identifier) @variable\n';

    String headed(QueryProvenance provenance) => withQueryHeader(
      body,
      queryHeader('queries/c/highlights.scm', provenance, _license),
    );

    test('reads back the file an unchanged import header names', () {
      final source = unchangedNvimSource(
        headed(
          const QueryProvenance(
            origin: QueryOrigin.nvim,
            changed: false,
            upstream: _nvimFile,
          ),
        ),
      );

      check(source).isNotNull()
        ..has((it) => it.repo, 'repo').equals(nvimTreesitterUrl)
        ..has((it) => it.commit, 'commit').equals(_nvimCommit)
        ..has((it) => it.path, 'path').equals(_nvimFile.path);
    });

    test('names nothing for a modified file, a grammar file or none', () {
      check(
        unchangedNvimSource(
          headed(
            const QueryProvenance(
              origin: QueryOrigin.nvim,
              changed: true,
              upstream: _nvimFile,
            ),
          ),
        ),
      ).isNull();
      check(
        unchangedNvimSource(
          headed(
            const QueryProvenance(
              origin: QueryOrigin.both,
              changed: false,
              upstream: UpstreamFile(
                repo: _grammarUrl,
                commit: _grammarCommit,
                path: 'queries/highlights.scm',
              ),
              nvimUpstream: _nvimFile,
            ),
          ),
        ),
      ).isNull();
      check(unchangedNvimSource(body)).isNull();
    });

    test('reads back a path with spaces, and no path but a .scm file', () {
      String header(String path) =>
          '; Derived from nvim-treesitter $nvimTreesitterUrl, '
          '$path @ $_nvimCommit, Apache-2.0.\n; Unchanged.\n\n$body';

      check(unchangedNvimSource(header('runtime/queries/my lang/folds.scm')))
          .isNotNull()
          .has((it) => it.path, 'path')
          .equals('runtime/queries/my lang/folds.scm');
      check(unchangedNvimSource(header('runtime/queries/c'))).isNull();
    });
  });

  group('queryHeaderProblems', () {
    const header = ['; Derived from nvim-treesitter x', '; Unchanged.'];
    const body = '(identifier) @variable\n';

    test('accepts exactly the header the provenance names', () {
      check(
        queryHeaderProblems('f.scm', withQueryHeader(body, header), header),
      ).isEmpty();
    });

    test('reports a missing, stale or unwanted header', () {
      check(queryHeaderProblems('f.scm', body, header)).length.equals(1);
      check(
        queryHeaderProblems(
          'f.scm',
          withQueryHeader(body, const [
            '; Derived from nvim-treesitter y',
            '; Unchanged.',
          ]),
          header,
        ),
      ).length.equals(1);
      check(
        queryHeaderProblems('f.scm', withQueryHeader(body, header), const []),
      ).length.equals(1);
    });

    test('reports a header line below the top of the file', () {
      final content =
          '${withQueryHeader(body, header)}'
          '; Derived from nvim-treesitter y\n';
      check(queryHeaderProblems('f.scm', content, header)).length.equals(1);
    });
  });
}
