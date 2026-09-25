; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, queries/cpp/injections.scm @ b5f203031282a6e9e025080fe71b58dbb43f7509, Apache-2.0.
; Modified in tree-sitter-grammars.

; Only patterns that name a language: a pattern naming none costs a
; match per node and injects nothing.

; Every comment carries the tags the comment grammar reads.
((comment) @injection.content
  (#set! injection.language "comment"))

; Raw string literals with language delimiter (e.g., R"cpp(...)cpp")
(raw_string_literal
  delimiter: (raw_string_delimiter) @injection.language
  (raw_string_content) @injection.content)
