[
  (package_declaration)
  (package_body)
  (subprogram_body)
  (subprogram_declaration)
  (if_statement)
  (handled_sequence_of_statements)
  (non_empty_declarative_part)
] @indent.begin

; Keywords that align with block opener (branches)
; Note: "is", "then", "loop" are typically inline with control statements
; and should NOT cause dedent on their own
[
  "end"
  "else"
  "elsif"
  "begin"
] @indent.branch
