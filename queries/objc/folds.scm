; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, runtime/queries/objc/folds.scm @ 692b051b09935653befdb8f7ba8afdb640adf17b, Apache-2.0.
; Modified in tree-sitter-grammars.

; Removed (if_statement) - fold compound_statement instead to keep else visible
; Removed (for_statement), (while_statement), (do_statement) for consistency
[
  (compound_statement)
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
] @fold
; inherits: c

[
  (class_declaration)
  (class_interface)
  (class_implementation)
  (protocol_declaration)
  (property_declaration)
  (method_declaration)
  (struct_declaration)
  (struct_declarator)
  (try_statement)
  (catch_clause)
  (finally_clause)
  (throw_statement)
  (block_literal)
  (ms_asm_block)
  (dictionary_literal)
  (array_literal)
] @fold
