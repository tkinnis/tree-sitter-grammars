[
  (function_definition)
  (object_definition)
  (block)
] @indent.begin

; Closing brace dedents
"}" @indent.dedent

; Closing parens/brackets mark scope boundaries but don't dedent
[
  ")"
  "]"
] @indent.end
