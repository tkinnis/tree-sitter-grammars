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
│   └── validate_queries.dart   # Query syntax validation
├── tree-sitter/                # tree-sitter core (submodule)
├── .github/workflows/
│   ├── build.yml               # CI build workflow
│   └── release.yml             # Release workflow
└── output/                     # Build output (gitignored)
    ├── libtree-sitter.{dylib,so,dll}
    ├── dylibs/
    │   └── <lang>/lib<lang>.{dylib,so,dll}
    └── queries/                # Copied from queries/
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
```

## Using Pre-built Binaries

Download platform-specific archives from [GitHub Releases](../../releases).

### Archive Contents

```
grammars-macos-arm64.tar.gz
├── libtree-sitter.dylib       # Core tree-sitter library
├── dylibs/
│   ├── c/
│   │   ├── libc.dylib
│   │   ├── config.json        # Language configuration
│   │   └── *.scm              # Query files
│   ├── dart/
│   │   ├── libdart.dylib
│   │   ├── config.json
│   │   └── *.scm
│   └── .../
└── grammars.sha256            # Content hash for version checking
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
| `config.json` | Language configuration (see below) |

### config.json Schema

Each language has a `config.json` with metadata and editor settings:

```json
{
  "displayName": "Ruby",
  "symbol": "ruby",
  "scope": "source.ruby",
  "extensions": [".rb"],
  "comments": {
    "line": "#",
    "block": ["=begin", "=end"]
  },
  "brackets": [
    {"open": "{", "close": "}", "autoClose": true, "newline": true},
    {"open": "(", "close": ")", "autoClose": true, "newline": false}
  ],
  "indentation": {
    "blockOpeners": ["{", "(", "["],
    "keywordOpeners": ["do", "then", "begin"],
    "lineStartKeywords": ["def", "class", "module", "if"],
    "dedentPairs": [
      {"open": "def", "close": "end"},
      {"open": "class", "close": "end"}
    ]
  },
  "queries": {
    "highlights": true,
    "folds": true,
    "indents": true
  }
}
```

| Field | Description |
|-------|-------------|
| `displayName` | Human-readable name |
| `symbol` | Entry point symbol name in native library |
| `scope` | TextMate scope for theme matching |
| `extensions` | File extensions (including dot) |
| `comments` | Comment delimiters for toggle/insertion |
| `brackets` | Auto-close and smart bracket settings |
| `indentation` | Heuristic indent settings for real-time typing |
| `queries` | Which query files are available |

## Creating Releases

Releases provide pre-built binaries for each platform. You can create releases automatically via GitHub Actions or manually from local builds.

### Option 1: Automated Releases (GitHub Actions)

Push a version tag to trigger the release workflow:

```bash
git tag v1.0.0
git push origin v1.0.0
```

The workflow builds for all platforms (macOS arm64/x64, Linux x64, Windows x64) and creates a GitHub release with the artifacts.

### Option 2: Manual Releases (Local Build)

For single-platform releases or when GitHub Actions aren't available:

#### Step 1: Build Locally

```bash
# Install prerequisites
npm install -g tree-sitter-cli
dart pub get

# Build all grammars (takes 15-30 minutes)
dart tool/build_tree_sitter_grammars.dart tool/grammars.json

# Copy queries to output
cp -R queries output/
```

#### Step 2: Create Release Archive

Determine your platform string:
- macOS ARM: `macos-arm64`
- macOS Intel: `macos-x64`
- Linux: `linux-x64`
- Windows: `windows-x64`

```bash
# macOS/Linux
cd output
tar -czvf ../grammars-<platform>.tar.gz .

# Windows (PowerShell)
cd output
Compress-Archive -Path * -DestinationPath ../grammars-windows-x64.zip
```

#### Step 3: Upload to GitHub Release

Using GitHub CLI:

```bash
# Install gh CLI (macOS)
brew install gh

# Authenticate (one-time setup)
gh auth login

# Create release and upload
gh release create v1.0.0 --title "v1.0.0" --notes "Initial release"
gh release upload v1.0.0 grammars-macos-arm64.tar.gz
```

Or manually via the GitHub web interface:
1. Go to your repository's Releases page
2. Click "Create a new release" or edit an existing one
3. Drag the archive file to the "Attach binaries" area
4. Publish the release

### Release Naming Convention

Archives must follow this naming pattern for the build hook to find them:

```
grammars-<platform>.tar.gz   # Unix
grammars-<platform>.zip      # Windows
```

Where `<platform>` is one of: `macos-arm64`, `macos-x64`, `linux-x64`, `windows-x64`

## License

Query files are sourced from [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) and individual grammar repositories. See each grammar repository for its specific license.

Tree-sitter is licensed under the MIT License.
