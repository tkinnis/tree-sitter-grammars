; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, queries/typescript/locals.scm @ 28bc7a070372c4ad6cbf3d98d4743b08defc0561, Apache-2.0.
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
  name: (type_identifier) @local.definition.class)

; Interface declarations
(interface_declaration
  name: (type_identifier) @local.definition.type)

; Type alias declarations
(type_alias_declaration
  name: (type_identifier) @local.definition.type)

; Variable declarations
(variable_declarator
  name: (identifier) @local.definition.var)

; Function/arrow parameters
(required_parameter
  (identifier) @local.definition.parameter)

(optional_parameter
  (identifier) @local.definition.parameter)

; Destructuring pattern identifiers (general fallback)
(pattern/identifier) @local.definition.var

; References
;------------

(identifier) @local.reference

(property_identifier) @local.reference

(type_identifier) @local.reference
