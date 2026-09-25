; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, runtime/queries/c/injections.scm @ 692b051b09935653befdb8f7ba8afdb640adf17b, Apache-2.0.
; Modified in tree-sitter-grammars.

; A macro's body is read as C, each body a document of its own: a body
; is often an expression or a fragment, and read together the bodies
; would parse as one malformed program. A directive's argument, #pragma's
; and #error's among them, is not C and is left as it is.
(preproc_def
  value: (preproc_arg) @injection.content
  (#set! injection.language "c"))

(preproc_function_def
  value: (preproc_arg) @injection.content
  (#set! injection.language "c"))

((comment) @injection.content
  (#set! injection.language "comment"))
