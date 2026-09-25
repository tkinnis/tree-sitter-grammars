; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, runtime/queries/proto/indents.scm @ 692b051b09935653befdb8f7ba8afdb640adf17b, Apache-2.0.
; Unchanged.

[
  (message_body)
  (enum_body)
] @indent.begin

"}" @indent.end @indent.branch

[
  (ERROR)
  (comment)
] @indent.auto
