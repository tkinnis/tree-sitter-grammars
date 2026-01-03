; Definitions
; -----------

(function_definition
  name: (name) @local.definition.function)

(method_declaration
  name: (name) @local.definition.method)

(class_declaration
  name: (name) @local.definition.class)

(interface_declaration
  name: (name) @local.definition.type)

(trait_declaration
  name: (name) @local.definition.type)

; Scopes
; ------

[
  (function_definition)
  (method_declaration)
  (class_declaration)
  (interface_declaration)
  (trait_declaration)
  (if_statement)
  (switch_statement)
  (while_statement)
  (do_statement)
  (for_statement)
  (foreach_statement)
  (compound_statement)
] @local.scope

; References
; ----------

; Variables like $name, $greeting
(variable_name) @local.reference

; Function calls - capture the function name
(function_call_expression
  function: (name) @local.reference)

; Method calls - capture the method name
(member_call_expression
  name: (name) @local.reference)

; Class instantiation
(object_creation_expression
  (name) @local.reference)

; Static method/property access
(scoped_call_expression
  scope: (name) @local.reference)
