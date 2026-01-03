[
  (class_declaration)
  (class_body)
  (object_declaration)
  (companion_object)
  (function_declaration)
  (function_body)
  (lambda_literal)
  (anonymous_initializer)
  (enum_class_body)
] @indent.begin

; Closing brace dedents the line
"}" @indent.dedent

; Closing parens/brackets mark scope boundaries but don't dedent
[
  ")"
  "]"
] @indent.end
