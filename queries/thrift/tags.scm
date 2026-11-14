(service_definition
  (identifier) @name) @definition.interface

(function_definition
  (identifier) @name) @definition.method

(struct_definition
  (identifier) @name) @definition.class

(union_definition
  (identifier) @name) @definition.class

(exception_definition
  (identifier) @name) @definition.class

(enum_definition
  type: (identifier) @name) @definition.enum

; Each value after the enum's name is its own identifier, apart from the
; number it may be given, so the identifier is the value's definition.
(enum_definition
  type: (identifier)
  (identifier) @name @definition.enum_member)

(senum_definition
  type: (identifier) @name) @definition.enum

(senum_definition
  (string) @name @definition.enum_member)

(typedef_definition
  (typedef_identifier) @name) @definition.type

(const_definition
  (identifier) @name) @definition.constant
