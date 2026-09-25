(class_declaration name: (identifier) @name) @definition.class

(class_declaration (base_list (_) @name)) @reference.class

(interface_declaration name: (identifier) @name) @definition.interface

(interface_declaration (base_list (_) @name)) @reference.interface

(struct_declaration name: (identifier) @name) @definition.struct

; A record is defined as a class, a record struct among them: the grammar
; marks a record struct only by its "struct" keyword, and no pattern can
; require a keyword to be absent.
(record_declaration name: (identifier) @name) @definition.class

(method_declaration name: (identifier) @name) @definition.method

(object_creation_expression type: (identifier) @name) @reference.class

(type_parameter_constraints_clause (identifier) @name) @reference.class

(type_parameter_constraint (type type: (identifier) @name)) @reference.class

(variable_declaration type: (identifier) @name) @reference.class

(invocation_expression function: (member_access_expression name: (identifier) @name)) @reference.send

(namespace_declaration name: (_) @name) @definition.module

; A file-scoped namespace holds every declaration after it in the file,
; which the grammar parses as the namespace's siblings, so its definition
; is the compilation unit, whose range holds them.
(compilation_unit
  (file_scoped_namespace_declaration name: (_) @name)) @definition.module

(namespace_declaration name: (identifier) @name) @module
