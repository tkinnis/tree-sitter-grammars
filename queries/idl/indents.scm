; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, runtime/queries/idl/indents.scm @ 692b051b09935653befdb8f7ba8afdb640adf17b, Apache-2.0.
; Modified in tree-sitter-grammars.

";" @indent.end

; Closing brace dedents
"}" @indent.dedent

(definition) @indent.begin

[
  (preproc_define)
  (preproc_include)
] @indent.ignore
