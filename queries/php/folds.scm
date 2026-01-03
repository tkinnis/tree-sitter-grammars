; inherits: php_only

; Removed if_statement from folds - fold compound_statement instead to keep else visible
; PHP if-else uses compound_statement for braced blocks
; NOTE: This means only braced if statements will fold properly.
; Alternative colon-block syntax (if: ... endif;) won't have individual branch folding.
[
  (function_definition)
  (method_declaration)
  (class_declaration)
  (interface_declaration)
  (trait_declaration)
  (enum_declaration)
  (namespace_definition)
  (switch_statement)
  (foreach_statement)
  (for_statement)
  (while_statement)
  (do_statement)
  (try_statement)
  (compound_statement)
] @fold
