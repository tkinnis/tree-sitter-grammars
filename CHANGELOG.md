# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/tkinnis/tree-sitter-grammars/compare/v1.0.2...HEAD
[1.0.2]: https://github.com/tkinnis/tree-sitter-grammars/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/tkinnis/tree-sitter-grammars/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/tkinnis/tree-sitter-grammars/releases/tag/v1.0.0
