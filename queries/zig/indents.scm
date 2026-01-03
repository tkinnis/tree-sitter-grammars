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
