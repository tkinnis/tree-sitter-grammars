; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, runtime/queries/zig/indents.scm @ 692b051b09935653befdb8f7ba8afdb640adf17b, Apache-2.0.
; Modified in tree-sitter-grammars.

[
  (block)
  (struct_declaration)
  (enum_declaration)
  (union_declaration)
  (switch_expression)
  (if_expression)
  (while_expression)
  (for_expression)
  (initializer_list)
] @indent.begin

; Closing brace dedents
"}" @indent.dedent

; Closing parens/brackets mark scope boundaries but don't dedent
[
  ")"
  "]"
] @indent.end

[
  (comment)
  (multiline_string)
] @indent.ignore
