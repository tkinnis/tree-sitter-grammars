; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, runtime/queries/objc/folds.scm @ 692b051b09935653befdb8f7ba8afdb640adf17b, Apache-2.0.
; Unchanged.

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
