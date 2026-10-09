# Contributing

Contributions are welcome: a grammar pin moved forward, a query fixed, a language added, a crash reproduced.

## Before you start

- Read [Building Locally](README.md#building-locally) and build once, so the toolchain, the pinned sources and the checks are in place.
- Every change keeps a release reproducible: grammars and the runtime are pinned to commits, and `THIRD_PARTY_NOTICES.md` is generated from those pins. Change a pin with `dart run tool/pin_grammars.dart`, never by hand, and regenerate the notices with `dart run tool/write_notices.dart`.

## Common changes

- **Moving a grammar forward:** `dart run tool/pin_grammars.dart --set tree-sitter-<lang>=<sha>`, then `--record-files`, then `dart run tool/write_notices.dart`, then a full build and `dart run tool/check_release.dart --against=<the previous archive>` to see what changed in the grammars.
- **Fixing a query:** edit the file under `queries/<language>/`, add or update a fixture under `test/highlights`, `test/tests`, `test/outline` or `test/injections`, and build. A query derived from nvim-treesitter keeps its provenance header; see [License](README.md#license).
- **Adding a language:** follow [Adding a New Language](README.md#adding-a-new-language).
- **Reporting a crash:** add the smallest input that reproduces it under `test/crashes`.

## Checks

```bash
dart test                                   # unit tests for the tools
dart run tool/build_tree_sitter_grammars.dart   # the full build, which runs every release check
```

The build refuses to run while `THIRD_PARTY_NOTICES.md` differs from what it generates, a pin lacks its recorded file digest, or a query file's provenance is missing.

## Pull requests

One concern per pull request, with a commit message that states what changes for a consumer. Releases are cut by the maintainer, as [Creating Releases](README.md#creating-releases) describes.
