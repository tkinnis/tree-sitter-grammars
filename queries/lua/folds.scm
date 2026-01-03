; Syntax-based folds. if_statement spans entire if-elseif-else chains,
; but indent-based folds are merged to provide granular branch folding.
[
  (do_statement)
  (while_statement)
  (repeat_statement)
  (if_statement)
  (for_statement)
  (function_declaration)
  (function_definition)
  (parameters)
  (arguments)
  (table_constructor)
] @fold
