; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, runtime/queries/ocaml/folds.scm @ 692b051b09935653befdb8f7ba8afdb640adf17b, Apache-2.0.
; Modified in tree-sitter-grammars.

; Control flow and expressions
[
  (if_expression)
  (match_expression)
  (try_expression)
  (fun_expression)
  (function_expression)
  (for_expression)
  (while_expression)
  (sequence_expression)
  (let_expression)
  (structure)
] @fold

; Definitions and bindings
[
  (let_binding)
  (external)
  (type_binding)
  (exception_definition)
  (module_binding)
  (module_type_definition)
  (open_module)
  (include_module)
  (include_module_type)
  (class_binding)
  (class_type_binding)
  (value_specification)
  (inheritance_specification)
  (instance_variable_specification)
  (method_specification)
  (inheritance_definition)
  (instance_variable_definition)
  (method_definition)
  (class_initializer)
  (match_case)
  (attribute)
  (item_attribute)
  (floating_attribute)
  (extension)
  (item_extension)
  (quoted_extension)
  (quoted_item_extension)
  (comment)
] @fold
