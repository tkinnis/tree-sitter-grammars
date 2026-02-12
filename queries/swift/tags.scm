(class_declaration
  name: (type_identifier) @name) @definition.class

(protocol_declaration
  name: (type_identifier) @name) @definition.interface

(function_declaration
  name: (simple_identifier) @name) @definition.function

(init_declaration
  "init" @name) @definition.method

(deinit_declaration
  "deinit" @name) @definition.method

(property_declaration
  (pattern
    (simple_identifier) @name)) @definition.property

(typealias_declaration
  name: (type_identifier) @name) @definition.type
