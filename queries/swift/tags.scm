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

; An extension declares members of the type it names, so its definition
; holds them as the type's own declaration does, named by the type as
; the extension writes it: `Outer.Inner` for one reached by a path, and
; `Array<Int>` with the arguments it is extended at.
(class_declaration
  declaration_kind: "extension"
  name: (user_type) @name) @definition.class
