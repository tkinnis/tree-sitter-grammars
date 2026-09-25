; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, runtime/queries/dart/locals.scm @ 692b051b09935653befdb8f7ba8afdb640adf17b, Apache-2.0.
; Unchanged.

; Definitions
(function_signature
  name: (identifier) @local.definition.function)

(formal_parameter
  name: (identifier) @local.definition.parameter)

(initialized_variable_definition
  name: (identifier) @local.definition.var)

(initialized_identifier
  (identifier) @local.definition.var)

(static_final_declaration
  (identifier) @local.definition.var)

; References
(identifier) @local.reference

; Scopes
(class_definition
  body: (_) @local.scope)

[
  (block)
  (if_statement)
  (for_statement)
  (while_statement)
  (try_statement)
  (catch_clause)
  (finally_clause)
] @local.scope
