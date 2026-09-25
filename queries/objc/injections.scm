; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, runtime/queries/objc/injections.scm @ 692b051b09935653befdb8f7ba8afdb640adf17b, Apache-2.0.
; Unchanged.

; inherits: c

; TODO(amaanq): uncomment/add when I add asm support
; (ms_asm_block "{" _ @asm "}")
;
; ((asm_specifier (string_literal) @asm)
;   (#offset! @asm 0 1 0 -1))
;
; ((asm_statement (string_literal) @asm)
;   (#offset! @asm 0 1 0 -1))
