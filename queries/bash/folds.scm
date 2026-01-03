; NOTE: Bash's if_statement spans the entire if-elif-else-fi chain.
; Folding if_statement will hide elif/else clauses. This is a known limitation
; as Bash's command structure doesn't have distinct block nodes.
[
  (function_definition)
  (if_statement)
  (case_statement)
  (for_statement)
  (while_statement)
  (c_style_for_statement)
  (heredoc_redirect)
] @fold
