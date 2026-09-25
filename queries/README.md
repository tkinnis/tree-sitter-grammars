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

These files are maintained here. The build copies every `.scm` file into the archive as it is, and each `config.json` with a `queries` map of the query files the language has added; it generates no query file. `tool/query_provenance.json` records where each one came from: nvim-treesitter, the grammar's own repository, both, or this repository.

## Adding a New Language

`tool/bootstrap_language.dart` imports the language's queries from nvim-treesitter at one commit, which each file's header and provenance entry record:

```bash
dart run tool/bootstrap_language.dart --language=<name>
```

After bootstrapping:

1. Adapt the imported queries. For every file you change, set `"changed": true` in its `tool/query_provenance.json` entry, then run `dart run tool/check_query_provenance.dart --write-headers`
2. Add symbol patterns to `tags.scm` for code navigation
3. Use the captures the editor maps to theme scopes, listed in `theme_scope_map.json` in finch's `origami_source` package

The bootstrap refuses a language whose other spelling, one nvim-treesitter names the same (`c_sharp` for `c-sharp`), has a directory here. It refuses a language that already has a directory here unless given `--force`, which replaces only what a bootstrap wrote there, removes an unchanged import of a query type the commit no longer has, and refuses a file that holds other work. The repository's README lists the remaining steps: pinning the grammar, the notices and the build.

### Limits of the Bootstrap

- It knows one language whose name differs from nvim-treesitter's: `c-sharp`, which nvim-treesitter names `c_sharp`. A grammar named differently in any other way needs an entry in the alias table in `tool/src/query_bootstrap.dart`, both for its queries to be found and for its other spelling to be refused.
- It imports highlights, folds, injections, locals and indents, and no other file: `tags.scm` is a placeholder to fill, and textobjects are left out.
- It copies each file as nvim-treesitter has it and compiles none of them. nvim-treesitter's own predicates and directives, and `; inherits:` lines naming a language this repository lacks, pass through as they are; `tool/check_release.dart` compiles the files when the grammar is built.
- The `config.json` skeleton is a guess: a display name made from the id, one extension named after it, C-style comments and the common brackets.
- It neither adds the grammar to `tool/grammars.json`, nor pins it, nor regenerates `THIRD_PARTY_NOTICES.md`.
- Every run fetches from nvim-treesitter, a dry run included, so it needs the network.
- Runs at once stage their files apart, but each rewrites `tool/query_provenance.json`, and its check that nothing changed since planning is not atomic with the rename. When two runs write at the same moment, the later one's file can drop the earlier one's entries, which rerunning that bootstrap with `--force` restores. Run one bootstrap at a time.
- A run killed while writing leaves its `.cache/bootstrap-staging-*` directory behind. No later run removes it; delete it by hand when no bootstrap is running.

## Customizing Queries

Edit files directly in `queries/<language>/`. A query change needs no change to any grammar library: the build copies each language's queries beside its library in the archive, and `tool/check_release.dart` compiles every one. A file taken from nvim-treesitter or a grammar's repository that you change needs `"changed": true` in its provenance entry and the header `check_query_provenance.dart --write-headers` then writes.

### Highlights

Captures in `highlights.scm` are mapped to TextMate scopes by the editor, through `theme_scope_map.json` in finch's `origami_source` package. Common captures:

- `@keyword` - language keywords
- `@function` - function names
- `@type` - type names
- `@string` - string literals
- `@comment` - comments

### Injections

A pattern in `injections.scm` marks a node's text as another language with `@injection.content`, and says which language either through a `(#set! injection.language "<name>")` directive on the pattern or through an `@injection.language` capture whose text names it. A pattern carrying neither matches and injects nothing, so it costs a query match per node for no result: `((comment) @injection.content)` alone is the shape that looks finished and does nothing. `tool/check_release.dart` refuses such a pattern in every grammar but those `injectionsNamingNoLanguage` in `tool/src/release_check.dart` lists, the grammars whose injections still hold one. A pattern that captures the node under any other name, such as `@glimmer`, injects nothing either, whatever language the name suggests, and `tool/check_release.dart` refuses it in every grammar.

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

The editor nests each definition under the definitions whose node's range holds it, so a method's outline entry spells its declaring scope. `tool/check_release.dart` runs a grammar's `tags.scm` over the sources under `test/outline/<grammar>/` and requires the outline beside each; the repository's README describes them.

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

Every query file comes from one of three places, and `tool/query_provenance.json` records which, with the closest upstream file and commit:

- **nvim-treesitter** ([nvim-treesitter/nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter)), under the Apache License 2.0. Each such file opens with a header naming the nvim-treesitter file and commit it derives from and whether it was modified here.
- **A grammar's own repository**, under that grammar's licence.
- **This repository**, under its MIT licence.

Some files carry lines from both of the first two; when such a file's closest upstream is the grammar's own file, its header names that file as well. `THIRD_PARTY_NOTICES.md` at the repository root lists every file by origin and reproduces each licence.

Each file cited is the closest one published under the licence the notices reproduce for its repository: the grammar's licence files at its pin, or nvim-treesitter's Apache License 2.0. Where an upstream changed its licence, or added one, the text is cited at a commit carrying that licence, never at an earlier one. `dart run tool/write_notices.dart` reads the licence and NOTICE files at every cited commit and fails unless they are the ones the notices reproduce.
