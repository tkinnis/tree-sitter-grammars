; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, queries/rust/injections.scm @ a4f4fcdd3ef1b36ebdad72741bbd85dd9ef5013e, Apache-2.0.
; Modified in tree-sitter-grammars.

((macro_invocation
  (token_tree) @injection.content)
 (#set! injection.language "rust")
 (#set! injection.include-children))

((macro_rule
  (token_tree) @injection.content)
 (#set! injection.language "rust")
 (#set! injection.include-children))

((line_comment) @injection.content
  (#set! injection.language "comment"))

((block_comment) @injection.content
  (#set! injection.language "comment"))
