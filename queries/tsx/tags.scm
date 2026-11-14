; TypeScript/TSX definitions
(class_declaration
  name: (type_identifier) @name) @definition.class

(interface_declaration
  name: (type_identifier) @name) @definition.interface

(enum_declaration
  name: (identifier) @name) @definition.enum

; A member written without a value is the enum body's own child, so its
; name is its definition.
(enum_body
  name: (_) @name @definition.enum_member)

(enum_assignment
  name: (_) @name) @definition.enum_member

(type_alias_declaration
  name: (type_identifier) @name) @definition.type

(function_declaration
  name: (identifier) @name) @definition.function

(method_definition
  name: (property_identifier) @name) @definition.method

(function_expression
  name: (identifier) @name) @definition.function

(variable_declarator
  name: (identifier) @name
  value: (arrow_function)) @definition.function

(variable_declarator
  name: (identifier) @name
  value: (function_expression)) @definition.function
