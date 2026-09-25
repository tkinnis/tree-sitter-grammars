; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, runtime/queries/objc/injections.scm @ 692b051b09935653befdb8f7ba8afdb640adf17b, Apache-2.0.
; Modified in tree-sitter-grammars.

; A macro's body is read as Objective-C, each body a document of its own; a
; directive's argument, #pragma's and #error's among them, is left as it is.
(preproc_def
  value: (preproc_arg) @injection.content
  (#set! injection.language "objc"))

(preproc_function_def
  value: (preproc_arg) @injection.content
  (#set! injection.language "objc"))

((comment) @injection.content
  (#set! injection.language "comment"))

; TODO(amaanq): uncomment/add when I add asm support
; (ms_asm_block "{" _ @asm "}")
;
; ((asm_specifier (string_literal) @asm)
;   (#offset! @asm 0 1 0 -1))
;
; ((asm_statement (string_literal) @asm)
;   (#offset! @asm 0 1 0 -1))
