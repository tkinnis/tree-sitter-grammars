(subprogram_declaration
  (procedure_specification
    name: (identifier) @name)) @definition.function

(subprogram_declaration
  (function_specification
    name: (identifier) @name)) @definition.function

(subprogram_body
  (procedure_specification
    name: (identifier) @name)) @definition.function

(subprogram_body
  (function_specification
    name: (identifier) @name)) @definition.function

(package_declaration
  name: (identifier) @name) @definition.module

(package_body
  name: (identifier) @name) @definition.module

(full_type_declaration
  (identifier) @name
  [
    (access_to_object_definition)
    (access_to_subprogram_definition)
    (array_type_definition)
    (decimal_fixed_point_definition)
    (derived_type_definition)
    (floating_point_definition)
    (interface_type_definition)
    (modular_type_definition)
    (ordinary_fixed_point_definition)
    (record_type_definition)
    (signed_integer_type_definition)
  ]) @definition.type

(full_type_declaration
  (identifier) @name
  (enumeration_type_definition)) @definition.enum

; An enumeration's literals are its own children, an identifier or a
; character literal each, so each literal is its definition.
(enumeration_type_definition
  [
    (identifier)
    (character_literal)
  ] @name @definition.enum_member)
