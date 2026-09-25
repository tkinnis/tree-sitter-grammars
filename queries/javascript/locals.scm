; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, queries/javascript/locals.scm @ 337756d2f632fa94461dbfddd73898568f46c43d, Apache-2.0.
; Taken from https://github.com/tree-sitter/tree-sitter-javascript, queries/locals.scm @ 9802cc5812a19cd28168076af36e88b463dd3a18, MIT.
; Modified in tree-sitter-grammars.

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
