(class_declaration
  (type_identifier) @name) @definition.class

(object_declaration
  (type_identifier) @name) @definition.class

(function_declaration
  (simple_identifier) @name) @definition.function

(class_declaration
  (class_body
    (function_declaration
      (simple_identifier) @name))) @definition.method

(property_declaration
  (variable_declaration
    (simple_identifier) @name)) @definition.property

(enum_entry
  (simple_identifier) @name) @definition.constant

(secondary_constructor
  "constructor" @name) @definition.method

(primary_constructor) @definition.method

(anonymous_initializer
  "init" @name) @definition.method
