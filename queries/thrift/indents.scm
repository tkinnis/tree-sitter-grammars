; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, runtime/queries/thrift/indents.scm @ 692b051b09935653befdb8f7ba8afdb640adf17b, Apache-2.0.
; Modified in tree-sitter-grammars.

(definition) @indent.begin

((parameters
  (parameter)) @indent.align
  (#set! "scope" "all"))

; Closing brace dedents
"}" @indent.dedent

; Closing delimiters mark scope boundaries but don't dedent
[
  ")"
] @indent.end

[
  (ERROR)
  (comment)
] @indent.auto
