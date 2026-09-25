; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, runtime/queries/php_only/folds.scm @ 692b051b09935653befdb8f7ba8afdb640adf17b, Apache-2.0.
; Modified in tree-sitter-grammars.

; No if_statement: php's own folds.scm folds each braced block
; (compound_statement), so an else branch stays visible.
[
  (switch_statement)
  (while_statement)
  (do_statement)
  (for_statement)
  (foreach_statement)
  (try_statement)
  (function_definition)
  (class_declaration)
  (interface_declaration)
  (trait_declaration)
  (enum_declaration)
  (function_static_declaration)
  (method_declaration)
  (namespace_use_declaration)+
] @fold
