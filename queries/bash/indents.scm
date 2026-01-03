[
  (function_definition)
  (compound_statement)
  (if_statement)
  (for_statement)
  (while_statement)
  (case_statement)
  (case_item)
  (do_group)
] @indent.begin

; Closing brace dedents
"}" @indent.dedent

; Closing keywords dedent to align with block opener
; Note: "then" and "do" are typically inline with control statements
; and should NOT cause dedent on their own
[
  "fi"
  "done"
  "esac"
  ";;"
] @indent.branch

[
  (elif_clause)
  (else_clause)
] @indent.branch
