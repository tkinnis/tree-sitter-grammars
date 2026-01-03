; Container structures that create an indent scope
[
  (class_body)
  (function_body)
  (function_expression_body)
  (block)
  (declaration
    (initializers))
  (switch_block)
  (formal_parameter_list)
  (formal_parameter)
  (list_literal)
  (arguments)
  (try_statement)
] @indent.begin

(switch_block
  (_) @indent.begin

)

[
  (switch_statement_case)
  (switch_statement_default)
] @indent.branch

; Closing braces dedent the line (they close blocks)
"}" @indent.dedent

; Closing parentheses/brackets mark scope boundaries but don't dedent
; (e.g., `)` in `if (condition)` shouldn't dedent)
[
  ")"
  "]"
] @indent.end

(comment) @indent.ignore

; dedenting the else block is painfully slow; replace with simpler strategy
; (if_statement) @indent.begin
; (if_statement
;   (block) @indent.branch)
(if_statement) @indent.auto
