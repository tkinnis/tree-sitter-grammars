; inherits: ecma,jsx

; Properties
;-----------

(property_identifier) @property

; Constants
;----------

([
    (identifier)
    (shorthand_property_identifier)
    (shorthand_property_identifier_pattern)
 ] @constant
 (#match? @constant "^[A-Z_][A-Z\\d_]+$"))

; Function and method definitions
;--------------------------------

(function_expression
  name: (identifier) @function)
(function_declaration
  name: (identifier) @function)
(method_definition
  name: (property_identifier) @function.method)
(method_definition
  name: (property_identifier) @constructor
  (#eq? @constructor "constructor"))

(pair
  key: (property_identifier) @function.method
  value: [(function_expression) (arrow_function)])

(assignment_expression
  left: (member_expression
    property: (property_identifier) @function.method)
  right: [(function_expression) (arrow_function)])

(variable_declarator
  name: (identifier) @function
  value: [(function_expression) (arrow_function)])

(assignment_expression
  left: (identifier) @function
  right: [(function_expression) (arrow_function)])

; Function and method calls
;--------------------------

(call_expression
  function: (identifier) @function)

(call_expression
  function: (member_expression
    property: (property_identifier) @function.method))

(call_expression
  function: (identifier) @function.builtin
  (#any-of? @function.builtin
    "eval" "isFinite" "isNaN" "parseFloat" "parseInt" "decodeURI"
    "decodeURIComponent" "encodeURI" "encodeURIComponent"))

(new_expression
  constructor: (identifier) @constructor)

; Special identifiers
;--------------------

((identifier) @variable.builtin
 (#match? @variable.builtin "^(arguments|module|console|window|document)$")
 (#is-not? local))

((identifier) @function.builtin
 (#eq? @function.builtin "require")
 (#is-not? local))

; Decorators
;-----------

(decorator
  (call_expression
    function: (identifier) @attribute))

(decorator
  (member_expression
    property: (property_identifier) @attribute))

(decorator
  (call_expression
    function: (member_expression
      property: (property_identifier) @attribute)))

; JSX
;----

(jsx_attribute
  (property_identifier) @tag.attribute)

(jsx_opening_element
  (member_expression
    (identifier)
    (property_identifier) @tag))

(jsx_closing_element
  (member_expression
    (identifier)
    (property_identifier) @tag))

(jsx_self_closing_element
  (member_expression
    (identifier)
    (property_identifier) @tag))

; Literals
;---------

(this) @variable.builtin
(super) @variable.builtin

[
  (true)
  (false)
  (null)
  (undefined)
] @constant.builtin

[
  (string)
  (template_string)
] @string

(regex) @string.special
(number) @number

; Tokens
;-------

[
  ";"
  (optional_chain)
  "."
  ","
] @punctuation.delimiter

; `/` is left to ecma, which captures it as an operator in a division
; and as a delimiter around a regular expression.
[
  "-"
  "--"
  "-="
  "+"
  "++"
  "+="
  "*"
  "*="
  "**"
  "**="
  "/="
  "%"
  "%="
  "<="
  "<<"
  "<<="
  "="
  "=="
  "==="
  "!"
  "!="
  "!=="
  "=>"
  ">="
  ">>"
  ">>="
  ">>>"
  ">>>="
  "~"
  "^"
  "&"
  "|"
  "^="
  "&="
  "|="
  "&&"
  "||"
  "??"
  "&&="
  "||="
  "??="
] @operator

[
  "("
  ")"
  "["
  "]"
  "{"
  "}"
]  @punctuation.bracket

(template_substitution
  "${" @punctuation.special
  "}" @punctuation.special) @embedded

(import_specifier "default" @keyword)
(export_specifier "default" @keyword)
(namespace_export "default" @keyword)
