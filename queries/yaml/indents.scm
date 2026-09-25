; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, runtime/queries/yaml/indents.scm @ 692b051b09935653befdb8f7ba8afdb640adf17b, Apache-2.0.
; Unchanged.

[
  (block_mapping_pair
    value: (block_node))
  (block_sequence_item)
] @indent.begin

(ERROR) @indent.auto
