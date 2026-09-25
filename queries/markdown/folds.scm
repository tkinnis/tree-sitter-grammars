; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, runtime/queries/markdown/folds.scm @ 692b051b09935653befdb8f7ba8afdb640adf17b, Apache-2.0.
; Modified in tree-sitter-grammars.

([
  (fenced_code_block)
  (indented_code_block)
  (list_item
    (list))
  (section)
] @fold
)

(section
  (list) @fold
)
