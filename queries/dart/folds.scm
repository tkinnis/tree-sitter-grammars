; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, runtime/queries/dart/folds.scm @ 692b051b09935653befdb8f7ba8afdb640adf17b, Apache-2.0.
; Unchanged.

[
  (class_definition)
  (enum_declaration)
  (extension_declaration)
  (arguments)
  (function_body)
  (block)
  (switch_block)
  (list_literal)
  (set_or_map_literal)
  (string_literal)
  (import_or_export)+
] @fold
