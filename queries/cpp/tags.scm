(struct_specifier name: (type_identifier) @name body:(_)) @definition.class

(declaration type: (union_specifier name: (type_identifier) @name)) @definition.class

(function_declarator declarator: (identifier) @name) @definition.function

(function_declarator declarator: (field_identifier) @name) @definition.function

(function_declarator declarator: (qualified_identifier scope: (namespace_identifier) @local.scope name: (identifier) @name)) @definition.method

; A typedef defines a type, apart from two typedefs of an enum with a
; body: one of an enum with no tag names that enum, so it defines the
; enum, and one under the enum's own tag adds no name to the enum the
; tag defines, so it defines nothing.
(type_definition
  type: [
    (class_specifier)
    (decltype)
    (dependent_type)
    (placeholder_type_specifier)
    (primitive_type)
    (qualified_identifier)
    (sized_type_specifier)
    (splice_type_specifier)
    (struct_specifier)
    (template_type)
    (type_identifier)
    (union_specifier)
  ]
  declarator: (type_identifier) @name) @definition.type

(type_definition
  type: (enum_specifier !body)
  declarator: (type_identifier) @name) @definition.type

(type_definition
  type: (enum_specifier name: (_) @_tag body: (_))
  declarator: (type_identifier) @name
  (#not-eq? @_tag @name)) @definition.type

(type_definition
  type: (enum_specifier !name body: (_))
  declarator: (type_identifier) @name) @definition.enum

(enum_specifier name: (_) @name body: (_)) @definition.enum

(enumerator name: (identifier) @name) @definition.enum_member

(class_specifier name: (type_identifier) @name) @definition.class
