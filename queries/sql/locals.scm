; Scopes
;-------

(program) @local.scope

(create_table) @local.scope

(create_view) @local.scope

(create_function) @local.scope

; Definitions
;------------

; Table definitions
(create_table
  (object_reference
    name: (identifier) @local.definition.type))

; View definitions
(create_view
  (object_reference
    name: (identifier) @local.definition.type))

; Function definitions
(create_function
  (object_reference
    name: (identifier) @local.definition.function))

; Column definitions
(column_definition
  name: (identifier) @local.definition.field)

; Function parameters
(function_argument
  (identifier) @local.definition.parameter)

; References
;-----------

; Table/view references
(object_reference
  name: (identifier) @local.reference)

; Column references
(column
  name: (identifier) @local.reference)

; General identifier references
(identifier) @local.reference
