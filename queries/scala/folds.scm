; Block-level folding for braced code
; Each block { } folds independently, enabling if/else independent folding
(block) @fold

[
  (class_definition)
  (trait_definition)
  (object_definition)
  (function_definition)
  (val_definition)
  (import_declaration)
  (while_expression)
  (do_while_expression)
  (for_expression)
  (try_expression)
  (match_expression)
  (case_block)
  (indented_block)
  (template_body)
  (enum_body)
  (lambda_expression)
] @fold
