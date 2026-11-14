(class_definition
  name: (identifier) @name) @definition.class

(object_definition
  name: (identifier) @name) @definition.class

(trait_definition
  name: (identifier) @name) @definition.interface

(enum_definition
  name: (_) @name) @definition.enum

[
  (simple_enum_case
    name: (_) @name)
  (full_enum_case
    name: (_) @name)
] @definition.enum_member

(function_definition
  name: (identifier) @name) @definition.function

(function_declaration
  name: (identifier) @name) @definition.function

(val_definition
  pattern: (identifier) @name) @definition.variable

(var_definition
  pattern: (identifier) @name) @definition.variable

(type_definition
  name: (type_identifier) @name) @definition.type
