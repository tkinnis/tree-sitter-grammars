(function_declaration
  name: (identifier) @name) @definition.function

; A declaration's name is its first named child, or the one after the
; library name of an `extern "c"` declaration; the identifiers after the
; name are its type and its value. A declaration whose value is an enum
; defines the enum, so it defines no variable.
((variable_declaration
  .
  [
    (identifier) @name
    ((string) . (identifier) @name)
  ]) @definition.variable
  (#not-match? @definition.variable "^[^=]*=\\s*enum\\b"))

; `"="` requires the enum to be the declaration's value rather than its
; type annotation, `var state: enum { ... } = .idle;`.
(variable_declaration
  .
  [
    (identifier) @name
    ((string) . (identifier) @name)
  ]
  "="
  (enum_declaration)) @definition.enum

; The fields of an enum that is a declaration's value are its members,
; apart from `_`, which marks the enum non-exhaustive. An enum in a type
; annotation or an expression defines no members.
(variable_declaration
  "="
  (enum_declaration
    (container_field
      name: (identifier) @name) @definition.enum_member)
  (#not-eq? @name "_"))
