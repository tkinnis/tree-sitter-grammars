((interface_header
  (identifier) @name) @definition.interface)

((struct_dcl
  (struct_def
    (identifier) @name)) @definition.type)

((except_dcl
  (identifier) @name) @definition.type)

((enum_dcl
  (identifier) @name) @definition.enum)

((enumerator
  (identifier) @name) @definition.enum_member)

((module_dcl
  (identifier) @name) @definition.module)

((op_dcl
  (identifier) @name) @definition.method)
