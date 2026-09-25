; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, runtime/queries/css/folds.scm @ 692b051b09935653befdb8f7ba8afdb640adf17b, Apache-2.0.
; Unchanged.

[
  ; top-level block statements from https://github.com/tree-sitter/tree-sitter-css/blob/master/grammar.js
  ; note: (block) is not used due to unideal behavior when node before block node spans multiple lines
  (rule_set)
  (at_rule)
  (supports_statement)
  (media_statement)
  (keyframe_block)
  (import_statement)+
] @fold
