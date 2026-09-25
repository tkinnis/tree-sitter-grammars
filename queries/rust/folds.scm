; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, runtime/queries/rust/folds.scm @ 692b051b09935653befdb8f7ba8afdb640adf17b, Apache-2.0.
; Modified in tree-sitter-grammars.

[
  (mod_item)
  (foreign_mod_item)
  (function_item)
  (struct_item)
  (trait_item)
  (enum_item)
  (impl_item)
  (type_item)
  (union_item)
  (const_item)
  (let_declaration)
  (loop_expression)
  (for_expression)
  (while_expression)
  ; Removed (if_expression) - fold block instead to keep else visible
  (match_expression)
  (call_expression)
  (array_expression)
  (macro_definition)
  (macro_invocation)
  (attribute_item)
  (block)
  (use_declaration)+
] @fold
