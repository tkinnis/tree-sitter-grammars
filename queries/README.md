# Tree-Sitter Query Files

This directory contains query files for syntax highlighting, code folding, indentation, and symbol extraction.

## Query Types

| File | Purpose |
|------|---------|
| `highlights.scm` | Syntax highlighting patterns |
| `folds.scm` | Code folding regions |
| `indents.scm` | Auto-indentation hints |
| `injections.scm` | Language injection (e.g., JS in HTML) |
| `locals.scm` | Local scope tracking for references |
| `tags.scm` | Symbol extraction for navigation |
| `textobjects.scm` | Text object selections (functions, classes, etc.) |

## Ownership

These files are maintained locally and are the source of truth. They are NOT generated or copied from external sources during the build process.

## Adding a New Language

Use `bootstrap_language.dart` to import queries from nvim-treesitter:

```bash
dart run tool/bootstrap_language.dart --language=<name>
```

This imports high-quality queries from the nvim-treesitter project as a starting point. After bootstrapping:

1. Review and customize the imported queries as needed
2. Add symbol patterns to `tags.scm` for code navigation
3. Ensure `highlights.scm` captures align with `theme_scope_map.json`

The bootstrap script will fail if queries already exist for a language. Use `--force` to overwrite (with caution).

## Customizing Queries

Edit files directly in `queries/<language>/`. Changes take effect immediately without rebuilding native libraries.

### Highlights

Captures in `highlights.scm` are mapped to TextMate scopes via `theme_scope_map.json`. Common captures:

- `@keyword` - language keywords
- `@function` - function names
- `@type` - type names
- `@string` - string literals
- `@comment` - comments

### Injections

A pattern in `injections.scm` marks a node's text as another language with `@injection.content`, and says which language either through a `(#set! injection.language "<name>")` directive on the pattern or through an `@injection.language` capture whose text names it. A pattern carrying neither matches and injects nothing, so it costs a query match per node for no result. `tool/convert_neovim_queries.dart` removes every `#set!` directive from the queries it imports, which is why a language bootstrapped from nvim-treesitter has to have its directives put back by hand — `((comment) @injection.content)` alone is the shape that looks finished and does nothing.

Every grammar whose comments are their own node injects `comment` into them, so a `TODO:`, `FIXME(user):` or `NOTE:` tag is read by the comment grammar wherever it is written; JavaScript, TypeScript and TSX inject `jsdoc` into a comment shaped like documentation as well, through a `#match?` on the comment's text, and the two are read side by side. The name a directive gives has to be a grammar in `tool/grammars.json` — `comment`, `regex`, `jsdoc`, `markdown_inline` and the rest — since the editor loads the injected language by that name, and a name no grammar answers to is a layer that never parses.

A predicate on an injection pattern — `#match?`, `#eq?`, `#any-of?` and their `not-` forms — is evaluated by the editor before the pattern injects, so a directive can be confined to the comments that look like documentation. Bash's `regex` nodes are left uninjected on purpose: the grammar files the pattern of a parameter expansion — `${file%.txt}` — under that node, and read as a regular expression it draws a shell glob in the wrong colours.

### Indentation

The `indents.scm` file defines auto-indentation behavior:

- `@indent.begin` - increases indent on next line
- `@indent.dedent` - decreases indent on current line
- `@indent.branch` - dedent before, indent after (e.g., `else`)

### Tags (Symbols)

The `tags.scm` file defines symbols for code navigation. Uses the tree-sitter standard tags format:

```scheme
(function_definition
  name: (identifier) @name) @definition.function

(class_definition
  name: (identifier) @name) @definition.class
```

## Language Configuration (config.json)

Each language directory may contain a `config.json` file with language-specific settings.

**Currently implemented:**
- Comments (line and block syntax)
- Brackets (matching, auto-close, newline behavior)
- Indentation fallback heuristics (used when the parser lags behind rapid typing)

### Schema

The schema is defined in `tool/language_config_schema.json`. Reference it in your config:

```json
{
  "$schema": "../../../../tool/language_config_schema.json",
  "comments": { ... },
  "brackets": [ ... ],
  "indentation": { ... }
}
```

### Comments

Configure comment syntax for comment toggling and auto-continuation:

| Property | Type | Description |
|----------|------|-------------|
| `line` | `string` | Line comment prefix (e.g., `//`, `#`, `--`) |
| `block` | `[string, string]` | Block comment delimiters [start, end] |

**Examples:**
```json
// C-style (Dart, JavaScript, Java, C/C++, Rust, Go)
{ "comments": { "line": "//", "block": ["/*", "*/"] } }

// Python, Ruby, Bash, YAML
{ "comments": { "line": "#" } }

// Lua, Ada
{ "comments": { "line": "--", "block": ["--[[", "]]"] } }

// HTML, XML
{ "comments": { "block": ["<!--", "-->"] } }

// Scheme, Common Lisp
{ "comments": { "line": ";", "block": ["#|", "|#"] } }
```

### Brackets

Configure bracket pairs for matching, highlighting, and auto-insertion:

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `open` | `string` | - | Opening bracket (e.g., `{`, `(`) |
| `close` | `string` | - | Closing bracket (e.g., `}`, `)`) |
| `autoClose` | `boolean` | `true` | Auto-insert closing bracket when opening is typed |
| `newline` | `boolean` | `false` | Add indented line when Enter pressed between pair |

**Example:**
```json
{
  "brackets": [
    {"open": "{", "close": "}", "autoClose": true, "newline": true},
    {"open": "(", "close": ")", "autoClose": true, "newline": false},
    {"open": "[", "close": "]", "autoClose": true, "newline": false}
  ]
}
```

### Auto-Close Before

The `autoCloseBefore` property controls which characters allow auto-close to trigger. Auto-close only happens if the cursor is before one of these characters (or at end of line).

```json
{ "autoCloseBefore": ";:.,=}])>'\"`" }
```

### Indentation Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `blockOpeners` | `string[]` | `["{", "(", "["]` | Tokens at END of line that increase indent |
| `lineStartBlockOpeners` | `string[]` | `[]` | Tokens at START of line that increase indent |
| `keywordOpeners` | `string[]` | `[]` | Keywords at END of line that increase indent |
| `lineStartKeywords` | `string[]` | `[]` | Keywords at START of line that increase indent |
| `colonOpensBlock` | `boolean` | `false` | Whether `:` at end of line increases indent |
| `dedentPairs` | `[{open, close}]` | `[{"{","}"}, {"(",")"}, {"[","]"}]` | Paired delimiters for heuristic dedent |

### Dedent Pairs

The `dedentPairs` property defines paired delimiters for heuristic dedent detection when the AST is stale. When a line starts with a `close` delimiter, the editor scans backwards counting open/close pairs to find the matching opener's indent level.

**Single-character pairs** (default): Use fast character-by-character counting.
```json
{ "dedentPairs": [{"open": "{", "close": "}"}, {"open": "(", "close": ")"}] }
```

**Multi-character pairs**: Use word-boundary matching to avoid false positives.
```json
{ "dedentPairs": [{"open": "begin", "close": "end"}] }
```

**Note:** For languages like Ruby where `end` closes many different openers (`if`, `def`, `class`, etc.), the AST-based approach via `indents.scm` handles this correctly. The heuristic `dedentPairs` is best suited for balanced bracket-style delimiters.

### When to Create config.json

Most languages work with the default `{`, `(`, `[` block openers. Only create `config.json` when a language needs non-default behavior:

**Python/YAML** - Use `colonOpensBlock: true`:
```json
{ "indentation": { "colonOpensBlock": true } }
```

**Ruby** - Has keyword-based blocks:
```json
{
  "indentation": {
    "blockOpeners": ["{", "(", "[", "|"],
    "keywordOpeners": ["do", "then", "begin"],
    "lineStartKeywords": ["def", "class", "module", "if", "unless", "case", "while", "until", "for"]
  }
}
```

**Lisp-family** (Scheme, Common Lisp, Clojure) - Opening paren at line start opens scope:
```json
{
  "indentation": {
    "blockOpeners": [],
    "lineStartBlockOpeners": ["("]
  }
}
```

### How Fallback Heuristics Work

1. **Primary**: AST-based indentation via `indents.scm` captures (`@indent.begin`, `@indent.dedent`)
2. **Fallback**: When the parser is still processing (stale cache), text-based heuristics from `config.json` are used
3. **Default**: Languages without `config.json` use `LanguageConfig.braceLanguage` defaults

This ensures responsive indentation even during rapid typing.

## Known Limitations

### Mermaid

The mermaid grammar ([mikkihugo/tree-sitter-mermaid](https://github.com/mikkihugo/tree-sitter-mermaid)) supports **one diagram per file**. This matches typical usage where each mermaid diagram is in its own markdown code block.

If you have multiple diagrams in a single file, only the first one will parse correctly. Split diagrams into separate files or use markdown with embedded code blocks for multiple diagrams.

## Source Attribution

Query files are initially imported from [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter), which provides community-tested queries for 300+ languages. We maintain our own `tags.scm` files using the tree-sitter standard tags format.
