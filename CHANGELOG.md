# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

## [1.0.0] - 2025-01-03

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

[Unreleased]: https://github.com/tkinnis/tree-sitter-grammars/compare/v1.0.3...HEAD
[1.0.3]: https://github.com/tkinnis/tree-sitter-grammars/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/tkinnis/tree-sitter-grammars/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/tkinnis/tree-sitter-grammars/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/tkinnis/tree-sitter-grammars/releases/tag/v1.0.0
