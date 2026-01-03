# Tree-Sitter Grammars

Pre-built tree-sitter grammar libraries and query files for syntax highlighting.

## Overview

This repository contains:

- **Query files** (`queries/`): Tree-sitter query files (.scm) for syntax highlighting, code folding, indentation, and more
- **Build infrastructure** (`tool/`): Dart scripts for building grammar libraries from source
- **GitHub Actions**: Automated builds for all supported platforms

## Supported Platforms

| Platform | Architecture | Library Extension |
|----------|-------------|-------------------|
| macOS | arm64 | `.dylib` |
| macOS | x64 | `.dylib` |
| Linux | x64 | `.so` |
| Windows | x64 | `.dll` |

## Supported Languages

50+ languages including: Ada, Bash, C, C++, C#, CSS, Dart, Go, Haskell, HTML, Java, JavaScript, JSON, Kotlin, Lua, Markdown, Objective-C, OCaml, Pascal, Perl, PHP, Python, Ruby, Rust, Scala, SQL, Swift, TypeScript, XML, YAML, Zig, and more.

See `tool/grammars.json` for the complete list.

## Repository Structure

```
tree-sitter-grammars/
├── queries/                    # Query files per language
│   ├── dart/
│   │   ├── config.json         # Language configuration
│   │   ├── highlights.scm      # Syntax highlighting
│   │   ├── folds.scm           # Code folding
│   │   ├── indents.scm         # Auto-indentation
│   │   ├── injections.scm      # Language injection
│   │   ├── locals.scm          # Scope analysis
│   │   └── tags.scm            # Symbol navigation
│   └── .../
├── tool/
│   ├── grammars.json           # Grammar repository configuration
│   ├── build_tree_sitter_grammars.dart  # Main build script
│   ├── bootstrap_language.dart # Import queries from nvim-treesitter
│   ├── validate_manifest.dart  # Manifest validation
│   └── validate_queries.dart   # Query syntax validation
├── tree-sitter/                # tree-sitter core (submodule)
├── .github/workflows/
│   ├── build.yml               # CI build workflow
│   └── release.yml             # Release workflow
└── output/                     # Build output (gitignored)
    ├── libtree-sitter.{dylib,so,dll}
    ├── dylibs/
    │   └── <lang>/lib<lang>.{dylib,so,dll}
    ├── queries/                # Copied from queries/
    └── manifest.json           # Runtime manifest
```

## Building Locally

### Prerequisites

- Dart SDK 3.5+
- Node.js 18+ (for tree-sitter-cli)
- C compiler (clang on macOS/Linux, MSVC on Windows)

### Build Steps

```bash
# Install tree-sitter CLI
npm install -g tree-sitter-cli

# Get Dart dependencies
dart pub get

# Build all grammars
dart tool/build_tree_sitter_grammars.dart tool/grammars.json

# Build options:
#   --force          Rebuild all grammars
#   --cleanup        Delete grammars/ after build
#   --manifest-only  Only regenerate manifest.json
```

## Using Pre-built Binaries

Download platform-specific archives from [GitHub Releases](../../releases).

### Archive Contents

```
grammars-macos-arm64.tar.gz
├── libtree-sitter.dylib       # Core tree-sitter library
├── dylibs/
│   ├── c/libc.dylib
│   ├── dart/libdart.dylib
│   └── .../
├── queries/
│   ├── c/
│   ├── dart/
│   └── .../
└── manifest.json              # Language metadata
```

## Adding a New Language

1. Add the grammar repository to `tool/grammars.json`:

```json
{
  "url": "https://github.com/user/tree-sitter-mylang",
  "name": "mylang",
  "scope": "source.mylang",
  "extensions": [".ml"]
}
```

2. Bootstrap query files from nvim-treesitter:

```bash
dart tool/bootstrap_language.dart --language=mylang
```

3. Customize queries in `queries/mylang/` as needed

4. Build and test:

```bash
dart tool/build_tree_sitter_grammars.dart tool/grammars.json
dart tool/validate_queries.dart
```

## Query File Types

| File | Purpose |
|------|---------|
| `highlights.scm` | Syntax highlighting patterns |
| `folds.scm` | Code folding regions |
| `indents.scm` | Auto-indentation rules |
| `injections.scm` | Language injection (e.g., JS in HTML) |
| `locals.scm` | Scope and variable tracking |
| `tags.scm` | Symbol extraction for navigation |
| `textobjects.scm` | Semantic text objects |
| `config.json` | Language configuration (comments, brackets) |

## License

Query files are sourced from [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) and individual grammar repositories. See each grammar repository for its specific license.

Tree-sitter is licensed under the MIT License.
