# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.1] - Unreleased

### Added

- Highlight tests: `tool/check_release.dart` parses every source under `test/highlights/<grammar>/` and requires what the grammar's composed `highlights.scm` draws in it, the latest pattern's capture over each span, to be the `.highlights` file beside it; the first are one source for each language below whose highlights change, each holding the spans where two patterns meet

### Fixed

Of two patterns that capture the same node, the later one is drawn. Patterns written for the opposite order, and patterns whose order overrode the one their author wrote for that node, are reordered or narrowed:

- JSON: a key is `@string.special.key`; its pattern came ahead of `(string) @string`, which drew every key as a string
- IDL: the base types, `wstring`, `wchar`, `long` and the rest, are `@type.builtin`, as the grammar's own highlight test expects, and not `@type`
- CSS: `(pseudo_element_selector "::" (tag_name) @attribute)` takes the name after `::` alone, so `button` in `button::before` is a tag and `before` an attribute
- Diff: an empty added or removed line is `@diff.plus` or `@diff.minus`, like every other added or removed line, and not the `@punctuation.special` of its `+` or `-`
- Mermaid: `"v" @keyword`, filed under packet diagrams, is removed; the grammar's only `"v"` is a flowchart's direction, which is `@keyword.directive`
- LaTeX: every delimiter of `\left` and `\right` is `@punctuation.delimiter`; a bracket was `@punctuation.bracket` and a parenthesis `@punctuation.delimiter`
- Rust: a capitalised name called like a function, `Ok(x)`, `Err(e)` or a tuple struct's `Wrapper(n)`, is `@constructor`, as the comment over its pattern says, and a macro's name `@function.macro`
- Swift: both the `?` and the `:` of a ternary are `@keyword.conditional.ternary`; the operator list drew the `?` as `@operator`
- Kotlin: the `@`, `file` and `:` of `@file:` are one `@attribute`; the delimiter list drew the `:` as `@punctuation.delimiter`
- Dart: `is` is `@keyword`, as tree-sitter-dart's own highlight test expects, and the `!` of `is!` is `@operator`; the `$`, `{` and `}` of an interpolation are `@punctuation.special`
- Scala: the name a `type` definition declares is `@type.definition`
- JavaScript, TypeScript and TSX: a keyword takes the name ecma gives it, `@keyword.conditional`, `@keyword.repeat`, `@keyword.import`, `@keyword.operator` and the rest; JavaScript and TypeScript each listed the same 41 keywords as `@keyword` after it. TypeScript draws the `as` of `x as T` as `@keyword`, and `import` and `export` are `@keyword.import`. A `/**` comment is `@comment.documentation`, which JavaScript's and TypeScript's own `(comment) @comment` overrode
- TSX: a JSX element's `<`, `>`, `</` and `/>` are `@tag.delimiter`, as in JavaScript
- Python: a call of a capitalised name, `Person(name)`, is `@constructor`
- Ruby: the `}` that closes `#{` is `@punctuation.special`, like the `#{`

A `#match?` regular expression taken from nvim-treesitter's `#lua-match?` is rewritten as a regular expression:

- JavaScript, TypeScript, TSX, Scala, Swift, Thrift and Protobuf: a `/**` comment over several lines is `@comment.documentation`; the `.` of its regular expression matched no line break
- SQL: an integer is `@number` and a decimal `@number.float`; their patterns kept Lua's `%d`, so every number was `@string`
- Java: the two patterns over documentation comments in `injections.scm` match `\s` in place of Lua's `%s`; neither names a language, so neither injects anything

## [1.2.0] - 2026-09-25

### Added

- C#: `tags.scm` defines every namespace as `@definition.module`: a block namespace under any name, qualified ones included, and a file-scoped namespace over the compilation unit that holds the declarations after it, so every class and method nests under its namespace in the editor's outline and a test's declaring scope reads `Namespace.Class`
- C#: `tags.scm` defines a struct as `@definition.struct` and a record as `@definition.class`, a record struct among them, so a method nests under the struct or record that declares it
- Outline tests: `tool/check_release.dart` parses every source under `test/outline/<grammar>/` and requires the outline of the definitions the grammar's composed `tags.scm` finds in it, nested by range as the editor nests its outline, to be the `.outline` file beside it; the first are three C# test files, for xUnit, NUnit and MSTest, and a C# source of structs and records
- Injection tests: `tool/check_release.dart` parses every source under `test/injections/<grammar>/` and requires what the grammar's composed `injections.scm` injects in it, as the editor injects it, to be the `.injections` file beside it: each injection's language, whether it is combined, and the whole text of the node it captures as `@injection.content`; the first are three Javadoc comments and a C, a C++ and an Objective-C source of macros and directives
- `tool/check_release.dart` refuses an injection pattern that captures no `@injection.content`, and one that captures it and names no language in every grammar but the twelve `injectionsNamingNoLanguage` in `tool/src/release_check.dart` lists (bash, go, html, java, kotlin, make, pascal, python, ruby, sql, xml and yaml, which hold 74), and requires every composed query to read as the patterns `ts_query_new` counts in it

### Changed

- `tool/check_release.dart --against` parses TypeScript's and JavaScript's inputs with tsx as well as the one example TypeScript's corpus names tsx in, since TSX is TypeScript with JSX

### Fixed

- Objective-C: folds, highlights, indents and locals take C's patterns through `; inherits: c` alone, and are nvim-treesitter's and tree-sitter-objc's text, unchanged. Each also held a copy of C's file, so C's patterns composed twice; folds' copy left out `for`, `while` and `do`
- C++: indents and locals take C's patterns through `; inherits: c` alone, holding no copy of C's file
- TSX: highlights and locals take TypeScript's patterns through `; inherits: typescript,jsx` alone, and injections inherits `typescript,jsx` in place of a copy of TypeScript's own patterns
- C, C++ and Objective-C: the body of every `#define` is injected as the file's own language, `c`, `cpp` or `objc`, each body a document of its own; a directive's argument, `#pragma`'s and `#error`'s among them, is not injected. C's re2c, doxygen and 70 printf patterns, which named no language and so injected nothing, are removed, since no grammar here compiles those languages. Objective-C's `injections.scm` holds its two `#define` patterns and a comment's in place of `; inherits: c` and a 1,155-line copy of C's file
- Markdown inline: an HTML tag is injected as `html`, combined, and a LaTeX block as `latex`, as nvim-treesitter's file has them
- Javadoc: the description of a `/**` comment and of each of its block tags is injected as `html`, and so is an `@see` tag's link from its `<`; the description of a `///` comment and of its block tag is injected as `markdown_inline`. A description inside an inline tag, a `{@snippet}` body among them, lies within the description around it and is not injected on its own. The two printf patterns of `@value` format strings, which named no language, are removed
- TypeScript, TSX and JavaScript: the `hbs` template pattern, which captured `@glimmer` in place of `@injection.content` and so injected nothing, is removed

## [1.1.0] - 2026-09-25

### Added

- `build_info.json` in the archive: the release, the runtime's tag, commit and language versions, the compiler's path and `--version` line, the SDK, the exact flags for the runtime and for grammars (with each grammar's include directories and install name), the git, gzip and tar that write the bundles and the archive, and the sha256 of every source bundle
- A `source` object on every compiled grammar's `manifest.json` entry: its repository, pinned commit (and `sourceCommit` for a deploy-branch pin), path, whether its parser is committed or generated, its ABI and its licence
- `tool/toolchain.json`, which pins the runtime, the tree-sitter CLI (by the sha256 of its release asset) and the macOS target
- `tool/pin_grammars.dart`, which pins every grammar in `tool/grammars.json` to one commit on its origin, with its licence, and checks the pins; `--from-checkouts` moves a pin only forward and keeps deploy pins, and no mode writes a result that fails the checks
- `THIRD_PARTY_NOTICES.md`, generated by `tool/write_notices.dart` and shipped in the archive: every licence and NOTICE file of the runtime and each pinned grammar, the licence comments of compiled sources (the runtime's `lib/src/portable/endian.h` and perl's `src/bsearch.h`), the query files' origins and the Apache License 2.0, verbatim; every upstream file a query file cites is at a commit whose licence and NOTICE files are the ones reproduced, which `tool/write_notices.dart` checks against each cited commit
- A header in each of the 174 query files derived from nvim-treesitter, naming its source file and commit and whether it was modified, checked and written by `tool/check_query_provenance.dart`
- `tool/check_release.dart`, which checks a build through the runtime it ships (exports, the manifest against `tool/grammars.json`, library load commands, ABI, every composed query and every language an `; inherits:` line names holding a file of its type, notices, source bundles) and compares it with an earlier archive with `--against`, evaluating each pattern's text predicates and comparing its directives
- A source bundle for the runtime and each pinned grammar repository, recorded by sha256 in `build_info.json` and attached to every release; `--sources=<dir>` rebuilds a release from its downloaded assets alone
- `filesSha256` on every pin, the digest of the files its tree holds, recorded by `tool/pin_grammars.dart` (`--record-files` records all of them); every tree the build compiles, from an object store or a downloaded bundle, is checked against it
- A bundle of what the pinned CLI generates for latex and swift, held to the `generatedSha256` their entries record and attached to every release, so a rebuild from a release's assets runs no CLI
- `--dry-run`, which builds and packs a release's bytes without its tag, and `--publish`, which creates the GitHub release of a pushed tag with the archive, its sha256, `build_info.json` and every source bundle, and refuses a release that exists or a tag on GitHub that does not name the built commit
- `pubspec.lock`, so `dart pub get` installs the package versions the tools were checked with

### Changed

- The runtime is tree-sitter v0.27.0 (`6070dbfefd326bd735e5683eb128cc1b57dad0c0`), compiled from its `lib/src/lib.c` by every build
- Every library targets macOS 13.0 (1.0.5's required macOS 15.0) and is compiled with `-O3` and tree-sitter's internal assertions on (`NDEBUG` is never defined), by Xcode's clang with an environment of `PATH`, `TMPDIR` and `DEVELOPER_DIR` only, so an inherited `CFLAGS`, `CPPFLAGS` or `LDFLAGS` changes nothing
- A grammar library links with no `-undefined dynamic_lookup`, so an unresolved symbol fails the build
- Every grammar compiles from its repository's committed `src/parser.c` at its pinned commit, extracted with `git archive` from `grammars/<repo>`, which serves only as a git object store; latex and swift, which commit no `parser.c`, are generated by the pinned CLI. perl and sql are pinned to their deploy branches (`0c24d001`, `51290616`), and swift to `8abb3e8b`, whose scanner allocates at least one byte
- Every build starts from empty `build/` and `output/` directories, and `output/` holds only a build that passed every check
- The release archive packs to the same bytes for the same build, and its sha256 is written beside it; `build_info.json` records the git, gzip and tar that write the bundles and the archive, and the bundles are written by `/usr/bin/git`
- `--release=vX.Y.Z` builds, checks and packs a clean working tree whose `HEAD` is the annotated tag, reading this repository's own files from that commit's tree rather than the working tree, and packs nothing if `HEAD` or the working tree changed while it ran; publishing is `--publish`
- `tool/bootstrap_language.dart` fetches nvim-treesitter into `.cache/nvim-treesitter` at `HEAD` or at a `--commit` one of its branches contains, records that commit in each imported file's header and `tool/query_provenance.json` entry, and checks everything it would write before writing any of it; it refuses a language whose other spelling (`c_sharp` for `c-sharp`) has queries, `--force` replaces only what a bootstrap wrote and refuses a file that holds other work, and each run stages its writes in a directory of its own
- `LICENSE` is the MIT licence of this repository's own work, held by Tony Kinnis; `LICENSES/Apache-2.0.txt` is nvim-treesitter's licence

### Fixed

- The archive's `libtree-sitter.dylib` is the one the build compiles: the build reused any runtime library it found in `tree-sitter/`, and every release from 1.0.0 through 1.0.5 shipped the same one (UUID `B2515C8E-453C-32FC-B616-24648A0981CA`)
- TSX: `indents.scm` has one `; inherits: typescript,jsx` line, taking TypeScript's block through inheritance
- PHP: `folds.scm` and `indents.scm` compose with `php_only`'s, the query-only language their `; inherits: php_only` line names, taken from nvim-treesitter; the archive held no `php_only`, so PHP shipped no indent query and folded no `function_static_declaration` or `namespace_use_declaration`. `php_only`'s folds leave out `if_statement`, which PHP's own folds leave out so an `else` stays visible

### Removed

- The two `cpp` injection patterns that named a language no grammar carries (`"c++"`)
- `queries/dot/`, which no grammar built or shipped
- `queries/ecma/locals.scm`, which no grammar's `locals.scm` inherits, so the editor never read it
- The build's `--force`, `--cleanup`, `--manifest-only` and `--archive` options, and its `npm install` of grammar dependencies
- `tool/validate_queries_treesitter.dart` and `tool/validate_queries.dart`, which `tool/check_release.dart` replaces
- `tool/build_tree_sitter.dart`, `tool/convert_neovim_queries.dart`, `tool/grammar_filters.json`, `tool/compare_configs.dart` and `tool/migrate_manifest_to_config.dart`, which no build step ran

## [1.0.5] - 2026-09-21

### Added

- The comment grammar ([stsewd/tree-sitter-comment](https://github.com/stsewd/tree-sitter-comment)), compiled like every other grammar, which reads a comment's tags such as `TODO`, `NOTE`, `HACK` and `FIXME`

### Changed

- Every host whose comments are their own node injects the comment grammar into them with `(#set! injection.language "comment")`; C++ and PHP name it in place of doxygen and phpdoc, which no grammar here compiles, and JavaScript, TypeScript and TSX inject jsdoc into a comment shaped like documentation and the comment grammar into every comment
- TSX's `injections.scm` inherits ecma and jsx through one `; inherits: ecma,jsx` line
- The comment grammar's highlights leave a tag's colon and brackets in the comment's colour

### Fixed

- The `((comment) @injection.content)` patterns that named no language, and so injected nothing, name the comment grammar
- The dtd `indents.scm` and `tags.scm` queries name the nodes the dtd grammar declares

## [1.0.4] - 2026-08-12

### Fixed

- Dart: `documentation_comment` now captures as `@comment.documentation` instead of `@comment`, so a `///` comment can be styled apart from an ordinary one

## [1.0.3] - 2026-02-11

### Added

- LaTeX grammar support with syntax highlighting, folds, and injections
- ECMAScript and JSX as query-only grammars
- Build script `--archive` and `--release=<ver>` options for automated releases
- Complete language config data in per-language config.json files:
  - `comments` (line and block comment syntax)
  - `brackets` (auto-close and indentation behavior)
  - `indentation` (language-specific indent rules)
  - `dedentPairs` for Ruby, Lua, Bash, and Ada

### Changed

- Manifest data merged into per-language config.json files
- Build script now copies full config.json from source instead of generating partial configs
- Build script now packages query-only grammars in `queries/` directory
- Bootstrap script creates complete config.json skeleton for new languages and updated for nvim-treesitter's new query path

### Fixed

- Dart: Removed redundant catch-all `method_signature` patterns that produced `<anonymous>` outline symbols for getters, setters, factory constructors, and named constructors
- CSS: Added `@name` capture to `tag_name` definition to prevent anonymous symbols
- Kotlin: Moved `@definition.method` scope from `class_declaration` to `function_declaration` for accurate method ranges; added `@name` capture to `primary_constructor`
- Swift: Added `"init"` and `"deinit"` name captures to constructor/destructor declarations
- Go: Added `@definition.variable` and `@definition.constant` captures to var/const declarations
- LaTeX: Fixed math environment highlighting, removed `@nospell` patterns, fixed Neovim-specific predicates, fixed capture names
- Haskell: Fixed choice block patterns and sibling patterns in `decl/function`
- Perl: Fixed `postfix_deref` query patterns that caused compilation errors
- Query-only grammars (html_tags, comment) now included in release archives

## [1.0.2] - 2026-01-05

### Changed

- Switched mermaid grammar to [mikkihugo/tree-sitter-mermaid](https://github.com/mikkihugo/tree-sitter-mermaid) for better parsing
  - Fixes keyword substring matching bug (e.g., "as" incorrectly highlighted inside "Fast")
  - Adds support for all 23 Mermaid diagram types
  - More comprehensive syntax highlighting coverage

### Fixed

- Mermaid grammar now correctly parses keywords without false positives
- Updated highlights.scm with complete node type coverage (590 rules)

### Note

- Mermaid grammar supports one diagram per file (by design - matches typical markdown code block usage)

## [1.0.1] - 2026-01-04

### Added

- Mermaid diagram language support with syntax highlighting for:
  - Sequence diagrams
  - Flowcharts
  - Class diagrams
  - State diagrams
  - Entity-relationship diagrams
  - Gantt charts
  - Pie charts

### Removed

- The GitHub Actions workflows `build.yml` and `release.yml`; releases are built by a local command

## [1.0.0] - 2026-01-03

### Added

- Initial release with 46 language grammars
- Pre-built binaries for macOS (arm64)
- Query files for syntax highlighting, code folding, indentation, and more
- Build infrastructure for compiling grammars from source
- GitHub Actions workflows for automated builds and releases

### Languages

Ada, Bash, C, C++, C#, Common Lisp, CSS, CSV, Dart, Diff, DTD, Go, Haskell,
HTML, IDL, Java, JavaDoc, JavaScript, JSDoc, JSON, JSX, Kotlin, Lua, Make,
Markdown, Objective-C, OCaml, Pascal, Perl, PHP, Proto, Python, Regex, Ruby,
Rust, Scala, Scheme, SQL, Swift, Thrift, TOML, TSX, TypeScript, XML, YAML, Zig

[1.1.0]: https://github.com/tkinnis/tree-sitter-grammars/compare/v1.0.5...v1.1.0
[1.0.5]: https://github.com/tkinnis/tree-sitter-grammars/compare/v1.0.4...v1.0.5
[1.0.4]: https://github.com/tkinnis/tree-sitter-grammars/compare/v1.0.3...v1.0.4
[1.0.3]: https://github.com/tkinnis/tree-sitter-grammars/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/tkinnis/tree-sitter-grammars/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/tkinnis/tree-sitter-grammars/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/tkinnis/tree-sitter-grammars/releases/tag/v1.0.0
