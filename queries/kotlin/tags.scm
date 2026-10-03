(class_declaration
  (type_identifier) @name) @definition.class

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
  (simple_identifier) @name) @definition.constant

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
