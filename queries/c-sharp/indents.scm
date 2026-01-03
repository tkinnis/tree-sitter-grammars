[
  (class_declaration)
  (namespace_declaration)
  (method_declaration)
  (constructor_declaration)
  (property_declaration)
  (accessor_list)
  (block)
  (if_statement)
  (for_statement)
  (while_statement)
  (switch_statement)
  (switch_section)
  (try_statement)
  (catch_clause)
  (finally_clause)
  (lambda_expression)
  (initializer_expression)
] @indent.begin

; Closing brace dedents the line
"}" @indent.dedent

; Closing parentheses/brackets mark scope boundaries but don't dedent
[
  ")"
  "]"
] @indent.end
