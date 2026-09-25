; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, runtime/queries/c/injections.scm @ 692b051b09935653befdb8f7ba8afdb640adf17b, Apache-2.0.
; Modified in tree-sitter-grammars.

; A macro's body and a directive's argument are read as C, in every file
; that inherits this one too.
((preproc_arg) @injection.content
  (#set! injection.language "c"))

((comment) @injection.content
  (#set! injection.language "comment"))
