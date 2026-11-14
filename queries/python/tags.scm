(function_definition
  name: (identifier) @name) @definition.function

; A class is an enum when a base it names is one of the `enum` module's
; enum classes, bare or reached through `enum`: `Enum`, `IntEnum`,
; `StrEnum`, `Flag`, `IntFlag` or `ReprEnum`. A base is what the list
; holds between its parentheses and commas, comments apart, so a keyword
; argument, `metaclass=...`, names no base, and neither does an argument
; of a call in the list, `make(Enum)`.
(class_definition
  name: (identifier) @name
  !superclasses) @definition.class

(class_definition
  name: (identifier) @name
  superclasses: (argument_list) @_bases
  (#not-match? @_bases "(^\\(|,)(\\s|#.*\\n)*(enum\\s*\\.\\s*)?(Enum|IntEnum|StrEnum|Flag|IntFlag|ReprEnum)(\\s|#.*\\n)*(,|\\)$)")) @definition.class

(class_definition
  name: (identifier) @name
  superclasses: (argument_list) @_bases
  (#match? @_bases "(^\\(|,)(\\s|#.*\\n)*(enum\\s*\\.\\s*)?(Enum|IntEnum|StrEnum|Flag|IntFlag|ReprEnum)(\\s|#.*\\n)*(,|\\)$)")) @definition.enum

(class_definition
  body: (block
    (function_definition
      name: (identifier) @name) @definition.method))

; An assignment defines a variable, apart from one directly in an enum's
; body that gives a value, which defines a member of the enum; an
; annotation there with no value, `size: int`, is a variable. The body
; of a class is a block whose parent is the class, so an assignment in any
; other block is a variable whatever class holds it.
(module
  (assignment
    left: [
      (identifier) @name
      (pattern_list (identifier) @name)
    ]) @definition.variable)

((block
  (assignment
    left: [
      (identifier) @name
      (pattern_list (identifier) @name)
    ]) @definition.variable) @_body
  (#not-has-parent? @_body class_definition))

(class_definition
  !superclasses
  body: (block
    (assignment
      left: [
        (identifier) @name
        (pattern_list (identifier) @name)
      ]) @definition.variable))

(class_definition
  superclasses: (argument_list) @_bases
  body: (block
    (assignment
      left: [
        (identifier) @name
        (pattern_list (identifier) @name)
      ]) @definition.variable)
  (#not-match? @_bases "(^\\(|,)(\\s|#.*\\n)*(enum\\s*\\.\\s*)?(Enum|IntEnum|StrEnum|Flag|IntFlag|ReprEnum)(\\s|#.*\\n)*(,|\\)$)"))

(class_definition
  superclasses: (argument_list) @_bases
  body: (block
    (assignment
      left: [
        (identifier) @name
        (pattern_list (identifier) @name)
      ]
      right: (_)) @definition.enum_member)
  (#match? @_bases "(^\\(|,)(\\s|#.*\\n)*(enum\\s*\\.\\s*)?(Enum|IntEnum|StrEnum|Flag|IntFlag|ReprEnum)(\\s|#.*\\n)*(,|\\)$)"))

(class_definition
  superclasses: (argument_list) @_bases
  body: (block
    (assignment
      left: (identifier) @name
      !right) @definition.variable)
  (#match? @_bases "(^\\(|,)(\\s|#.*\\n)*(enum\\s*\\.\\s*)?(Enum|IntEnum|StrEnum|Flag|IntFlag|ReprEnum)(\\s|#.*\\n)*(,|\\)$)"))

; The assignments a chained assignment holds after its first, `b` in
; `a = b = 1`, are variables wherever it is.
(assignment
  right: (assignment
    left: [
      (identifier) @name
      (pattern_list (identifier) @name)
    ]) @definition.variable)

(parameters
  (identifier) @name) @definition.parameter

(typed_parameter
  (identifier) @name) @definition.parameter

(typed_default_parameter
  (identifier) @name) @definition.parameter
