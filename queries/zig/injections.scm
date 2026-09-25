; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, runtime/queries/zig/injections.scm @ 692b051b09935653befdb8f7ba8afdb640adf17b, Apache-2.0.
; Modified in tree-sitter-grammars.

((comment) @injection.content
  (#set! injection.language "comment"))

; TODO: add when asm is added
; (asm_output_item (string) @injection.content
; ;
; )
; (asm_input_item (string) @injection.content
; ;
; )
; (asm_clobbers (string) @injection.content
; ;
; )
