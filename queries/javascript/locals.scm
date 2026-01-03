; Scopes
;-------

[
  (statement_block)
  (function_expression)
  (arrow_function)
  (function_declaration)
  (method_definition)
  (class_body)
  (for_statement)
  (for_in_statement)
  (catch_clause)
] @local.scope

; Definitions
;------------

; Function declarations
(function_declaration
  name: (identifier) @local.definition.function)

; Method definitions in classes
(method_definition
  name: (property_identifier) @local.definition.method)

; Class declarations
(class_declaration
  name: (identifier) @local.definition.class)

; Variable declarations
(variable_declarator
  name: (identifier) @local.definition.var)

; Function/arrow parameters
(formal_parameters
  (identifier) @local.definition.parameter)

; Destructuring pattern identifiers (general fallback)
(pattern/identifier) @local.definition.var

; References
;------------

(identifier) @local.reference

(property_identifier) @local.reference
