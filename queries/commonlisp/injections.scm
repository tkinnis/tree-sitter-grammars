; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, runtime/queries/commonlisp/injections.scm @ 692b051b09935653befdb8f7ba8afdb640adf17b, Apache-2.0.
; Unchanged.

([
  (comment)
  (block_comment)
] @injection.content
  (#set! injection.language "comment"))
