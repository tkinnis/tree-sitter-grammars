; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, runtime/queries/lua/folds.scm @ 692b051b09935653befdb8f7ba8afdb640adf17b, Apache-2.0.
; Modified in tree-sitter-grammars.

; Syntax-based folds. if_statement spans entire if-elseif-else chains,
; but indent-based folds are merged to provide granular branch folding.
[
  (do_statement)
  (while_statement)
  (repeat_statement)
  (if_statement)
  (for_statement)
  (function_declaration)
  (function_definition)
  (parameters)
  (arguments)
  (table_constructor)
] @fold
