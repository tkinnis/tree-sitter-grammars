; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, runtime/queries/scala/injections.scm @ 024e6c5e46f8ec4237695b9e3020ecb601d817df, Apache-2.0.
; Unchanged.

((comment) @injection.content
  (#set! injection.language "comment"))

((block_comment) @injection.content
  (#set! injection.language "comment"))
