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
  (identifier) @name
  (#not-match? @name "^[A-Z_]+$")) @definition.enum

(typedef_definition
  (typedef_identifier) @name) @definition.type

(const_definition
  (identifier) @name) @definition.constant
