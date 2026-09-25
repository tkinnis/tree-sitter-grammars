; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, runtime/queries/zig/folds.scm @ 692b051b09935653befdb8f7ba8afdb640adf17b, Apache-2.0.
; Taken from https://github.com/tree-sitter-grammars/tree-sitter-zig, queries/folds.scm @ b3d906d56ab4c5839581deae3a1ca7d83c38e756, MIT.
; Modified in tree-sitter-grammars.

; Removed (if_statement), (if_expression), (else_clause), (if_type_expression) - fold block instead to keep else visible
[
  (block)
  (switch_expression)
  (initializer_list)
  (asm_expression)
  (multiline_string)
  (while_statement)
  (for_statement)
  (for_expression)
  (while_expression)
  (function_signature)
  (parameters)
  (call_expression)
  (struct_declaration)
  (opaque_declaration)
  (enum_declaration)
  (union_declaration)
  (error_set_declaration)
] @fold
