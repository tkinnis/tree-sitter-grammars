[
  (array)
  (inline_table)
] @indent.begin

; Closing brace dedents
"}" @indent.dedent

; Closing brackets mark scope boundaries but don't dedent
"]" @indent.end
