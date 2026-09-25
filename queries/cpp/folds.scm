; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, runtime/queries/cpp/folds.scm @ 692b051b09935653befdb8f7ba8afdb640adf17b, Apache-2.0.
; Modified in tree-sitter-grammars.

; inherits: c

[
  ; C patterns
  (for_statement)
  ; Removed (if_statement) - fold compound_statement instead to keep else visible
  (while_statement)
  (do_statement)
  (switch_statement)
  (case_statement)
  (function_definition)
  (struct_specifier)
  (enum_specifier)
  (comment)
  (preproc_if)
  (preproc_elif)
  (preproc_else)
  (preproc_ifdef)
  (preproc_function_def)
  (initializer_list)
  (gnu_asm_expression)
  (preproc_include)+
  (compound_statement)

  ; C++ specific patterns
  (for_range_loop)
  (class_specifier)
  (field_declaration
    type: (enum_specifier)
    default_value: (initializer_list))
  (template_declaration)
  (namespace_definition)
  (try_statement)
  (catch_clause)
  (lambda_expression)
] @fold
