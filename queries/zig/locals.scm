; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, runtime/queries/zig/locals.scm @ 692b051b09935653befdb8f7ba8afdb640adf17b, Apache-2.0.
; Modified in tree-sitter-grammars.

; Definitions
(function_declaration
  name: (identifier) @local.definition.function)

(parameter
  name: (identifier) @local.definition.parameter)

(variable_declaration
  (identifier) @local.definition.var)

(variable_declaration
  (identifier) @local.definition.type
  (enum_declaration))

(container_field
  type: (identifier) @local.definition.field)

(enum_declaration
  (function_declaration
    name: (identifier) @local.definition.method))

(variable_declaration
  (identifier) @local.definition.type
  (struct_declaration))

(struct_declaration
  (function_declaration
    name: (identifier) @local.definition.method))

(container_field
  name: (identifier) @local.definition.field)

(variable_declaration
  (identifier) @local.definition.type
  (union_declaration))

(union_declaration
  (function_declaration
    name: (identifier) @local.definition.method))

(payload
  (identifier) @local.definition.var)

(block_label
  (identifier) @local.definition)

; References
(identifier) @local.reference

(parameter
  type: (identifier) @local.reference
)

(pointer_type
  (identifier) @local.reference
)

(nullable_type
  (identifier) @local.reference
)

(struct_initializer
  (identifier) @local.reference
)

(array_type
  (_)
  (identifier) @local.reference
)

(slice_type
  (identifier) @local.reference
)

(field_expression
  member: (identifier) @local.reference
)

(call_expression
  function: (field_expression
    member: (identifier) @local.reference
))

(break_label
  (identifier) @local.reference)

[
  (for_statement)
  (if_statement)
  (while_statement)
  (function_declaration)
  (block)
  (source_file)
  (enum_declaration)
  (struct_declaration)
] @local.scope
