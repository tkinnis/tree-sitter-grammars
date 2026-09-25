; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, runtime/queries/go/folds.scm @ 692b051b09935653befdb8f7ba8afdb640adf17b, Apache-2.0.
; Modified in tree-sitter-grammars.

[
  (const_declaration)
  (expression_switch_statement)
  (expression_case)
  (default_case)
  (type_switch_statement)
  (type_case)
  (for_statement)
  (func_literal)
  (function_declaration)
  ; Removed (if_statement) - fold blocks instead to keep else visible
  (import_declaration)
  (method_declaration)
  (type_declaration)
  (var_declaration)
  (composite_literal)
  (literal_element)
  (block)
] @fold
