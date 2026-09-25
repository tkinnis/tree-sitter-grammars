; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, runtime/queries/css/indents.scm @ 692b051b09935653befdb8f7ba8afdb640adf17b, Apache-2.0.
; Modified in tree-sitter-grammars.

[
  (block)
  (declaration)
] @indent.begin

; Closing brace dedents
"}" @indent.dedent

(comment) @indent.ignore
