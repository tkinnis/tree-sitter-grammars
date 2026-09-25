; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, runtime/queries/ecma/folds.scm @ 692b051b09935653befdb8f7ba8afdb640adf17b, Apache-2.0.
; Modified in tree-sitter-grammars.

[
  (arguments)
  (for_in_statement)
  (for_statement)
  (while_statement)
  (arrow_function)
  (function_expression)
  (function_declaration)
  (class_declaration)
  (method_definition)
  (do_statement)
  (with_statement)
  (switch_statement)
  (switch_case)
  (switch_default)
  (import_statement)+
  ; Removed (if_statement) - fold statement_block instead to keep else visible
  (statement_block)
  (try_statement)
  (catch_clause)
  (array)
  (object)
  (generator_function)
  (generator_function_declaration)
] @fold
