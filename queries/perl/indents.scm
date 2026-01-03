[
  (block)
  (subroutine_declaration_statement)
] @indent.begin

; Closing brace dedents
"}" @indent.dedent

; Closing parens/brackets mark scope boundaries but don't dedent
[
  ")"
  "]"
] @indent.end
