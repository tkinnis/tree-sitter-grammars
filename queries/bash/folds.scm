; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, runtime/queries/bash/folds.scm @ 692b051b09935653befdb8f7ba8afdb640adf17b, Apache-2.0.
; Modified in tree-sitter-grammars.

; NOTE: Bash's if_statement spans the entire if-elif-else-fi chain.
; Folding if_statement will hide elif/else clauses. This is a known limitation
; as Bash's command structure doesn't have distinct block nodes.
[
  (function_definition)
  (if_statement)
  (case_statement)
  (for_statement)
  (while_statement)
  (c_style_for_statement)
  (heredoc_redirect)
] @fold
