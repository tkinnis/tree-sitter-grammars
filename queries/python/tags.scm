(function_definition
  name: (identifier) @name) @definition.function

; A class is an enum when a direct `identifier` or `attribute` child of its
; `superclasses` list names one of the `enum` module's enum classes, bare or
; reached through `enum`: `Enum`, `IntEnum`, `StrEnum`, `Flag`, `IntFlag` or
; `ReprEnum`. Comments, subscripts (`Generic[str, Enum, int]`), calls
; (`make(Enum)`) and keyword arguments (`metaclass=...`) are other node types,
; so none of them names a base. `@definition.enum` precedes `@definition.class`,
; and `[(identifier) @_base (attribute) @_base _]*` gathers every direct
; `identifier` or `attribute` base into one match while stepping past commas,
; comments and other expressions, so `#not-match?` refuses the class whenever
; any base is an enum class and an editor that checks only the first captured
; node keeps `@definition.enum` over `@definition.class` on equal priority.
(class_definition
  name: (identifier) @name
  superclasses: (argument_list
    [(identifier) (attribute)] @_base)
  (#match? @_base "^(enum\\s*\\.\\s*)?(Enum|IntEnum|StrEnum|Flag|IntFlag|ReprEnum)$")) @definition.enum

(class_definition
  name: (identifier) @name
  !superclasses) @definition.class

(class_definition
  name: (identifier) @name
  superclasses: (argument_list
    [(identifier) @_base (attribute) @_base _]*)
  (#not-match? @_base "^(enum\\s*\\.\\s*)?(Enum|IntEnum|StrEnum|Flag|IntFlag|ReprEnum)$")) @definition.class

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
  superclasses: (argument_list
    [(identifier) @_base (attribute) @_base _]*)
  body: (block
    (assignment
      left: [
        (identifier) @name
        (pattern_list (identifier) @name)
      ]) @definition.variable)
  (#not-match? @_base "^(enum\\s*\\.\\s*)?(Enum|IntEnum|StrEnum|Flag|IntFlag|ReprEnum)$"))

(class_definition
  superclasses: (argument_list
    [(identifier) (attribute)] @_base)
  body: (block
    (assignment
      left: [
        (identifier) @name
        (pattern_list (identifier) @name)
      ]
      right: (_)) @definition.enum_member)
  (#match? @_base "^(enum\\s*\\.\\s*)?(Enum|IntEnum|StrEnum|Flag|IntFlag|ReprEnum)$"))

(class_definition
  superclasses: (argument_list
    [(identifier) (attribute)] @_base)
  body: (block
    (assignment
      left: (identifier) @name
      !right) @definition.variable)
  (#match? @_base "^(enum\\s*\\.\\s*)?(Enum|IntEnum|StrEnum|Flag|IntFlag|ReprEnum)$"))

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
