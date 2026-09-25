; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, runtime/queries/kotlin/locals.scm @ 692b051b09935653befdb8f7ba8afdb640adf17b, Apache-2.0.
; Modified in tree-sitter-grammars.

; Imports
(package_header
  .
  (identifier) @local.definition.namespace)

(import_header
  (identifier
    (simple_identifier) @local.definition.import .)
  (import_alias
    (type_identifier) @local.definition.import)?)

; Functions
(function_declaration
  .
  (simple_identifier) @local.definition.function
)

(class_body
  (function_declaration
    .
    (simple_identifier) @local.definition.method)
)

; Variables
(function_declaration
  (function_value_parameters
    (parameter
      (simple_identifier) @local.definition.parameter)))

(lambda_literal
  (lambda_parameters
    (variable_declaration
      (simple_identifier) @local.definition.parameter)))

; NOTE: temporary fix for treesitter bug that causes delay in file opening
;(class_body
;  (property_declaration
;    (variable_declaration
;      (simple_identifier) @local.definition.field)))
(class_declaration
  (primary_constructor
    (class_parameter
      (simple_identifier) @local.definition.field)))

(enum_class_body
  (enum_entry
    (simple_identifier) @local.definition.field))

(variable_declaration
  (simple_identifier) @local.definition.var)

; Types
(class_declaration
  (type_identifier) @local.definition.type
)

(type_alias
  (type_identifier) @local.definition.type
)

; Scopes
[
  (if_expression)
  (when_expression)
  (when_entry)
  (for_statement)
  (while_statement)
  (do_while_statement)
  (lambda_literal)
  (function_declaration)
  (primary_constructor)
  (secondary_constructor)
  (anonymous_initializer)
  (class_declaration)
  (enum_class_body)
  (enum_entry)
  (interpolated_expression)
] @local.scope

; References
(simple_identifier) @local.reference
