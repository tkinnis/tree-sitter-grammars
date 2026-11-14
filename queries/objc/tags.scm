((class_interface
  (identifier) @name) @definition.class)

((class_implementation
  (identifier) @name) @definition.class)

((protocol_declaration
  (identifier) @name) @definition.interface)

((method_declaration
  (identifier) @name) @definition.method)

((method_definition
  (identifier) @name) @definition.method)

((function_definition
  declarator: (function_declarator
    declarator: (identifier) @name)) @definition.function)

((type_definition
  type: (enum_specifier !name body: (_))
  declarator: (type_identifier) @name) @definition.enum)

((enum_specifier
  name: (type_identifier) @name
  body: (_)) @definition.enum)

((enumerator
  name: (identifier) @name) @definition.enum_member)
