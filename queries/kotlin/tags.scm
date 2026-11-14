; The grammar marks an enum class only by its body and an "enum" keyword,
; which no pattern can require to be absent, so a class is told from an
; enum by what ends its declaration: a class body, its name, or a part of
; its header.
(class_declaration
  (type_identifier) @name
  (class_body)) @definition.class

(class_declaration
  (type_identifier) @name .) @definition.class

(class_declaration
  (type_identifier) @name
  [
    (type_parameters)
    (primary_constructor)
    (delegation_specifier)
    (type_constraints)
  ] .) @definition.class

(class_declaration
  (type_identifier) @name
  (enum_class_body)) @definition.enum

(object_declaration
  (type_identifier) @name) @definition.class

(function_declaration
  (simple_identifier) @name) @definition.function

(class_declaration
  (class_body
    (function_declaration
      (simple_identifier) @name) @definition.method))

(property_declaration
  (variable_declaration
    (simple_identifier) @name)) @definition.property

(enum_entry
  (simple_identifier) @name) @definition.enum_member

(secondary_constructor
  "constructor" @name) @definition.method

(primary_constructor
  "constructor" @name) @definition.method

(anonymous_initializer
  "init" @name) @definition.method

; A package header names the package of every declaration after it in
; the file, which the grammar parses as the header's siblings, so its
; definition is the source file, whose range holds them.
(source_file
  (package_header
    (identifier) @name)) @definition.package
