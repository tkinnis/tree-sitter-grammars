[
  (object)
  (array)
] @indent.begin

; Closing brace dedents
"}" @indent.dedent

; Closing bracket marks scope boundary but doesn't dedent
"]" @indent.end
