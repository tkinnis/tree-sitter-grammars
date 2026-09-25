; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, runtime/queries/markdown_inline/injections.scm @ 692b051b09935653befdb8f7ba8afdb640adf17b, Apache-2.0.
; Unchanged.

((html_tag) @injection.content
  (#set! injection.language "html")
  (#set! injection.combined))

((latex_block) @injection.content
  (#set! injection.language "latex")
  (#set! injection.include-children))
