(class_declaration
  name: (identifier) @name) @definition.class

(constructor_declaration
  name: (identifier) @name) @definition.constructor

(method_declaration
  name: (identifier) @name) @definition.method

(method_invocation
  name: (identifier) @name
  arguments: (argument_list) @reference.call)

(interface_declaration
  name: (identifier) @name) @definition.interface

(type_list
  (type_identifier) @name) @reference.implementation

(object_creation_expression
  type: (type_identifier) @name) @reference.class

(superclass (type_identifier) @name) @reference.class

; A package declaration names the package of every declaration after it
; in the file, which the grammar parses as the declaration's siblings, so
; its definition is the program, whose range holds them.
(program
  (package_declaration
    [(identifier) (scoped_identifier)] @name)) @definition.package
