; Support for folding in Ada
; NOTE: Ada's if_statement spans the entire if-elsif-else chain.
; Folding if_statement will hide elsif/else clauses. This is a known limitation.
[
  (package_declaration)
  (generic_package_declaration)
  (package_body)
  (subprogram_body)
  (block_statement)
  (if_statement)
  (loop_statement)
  (gnatprep_declarative_if_statement)
  (gnatprep_if_statement)
] @fold
