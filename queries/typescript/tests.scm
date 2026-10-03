; inherits: ecma

(required_parameter
  pattern: (identifier) @rebinding
  (#any-of? @rebinding "describe" "context" "suite" "fdescribe" "xdescribe"))

(optional_parameter
  pattern: (identifier) @rebinding
  (#any-of? @rebinding "describe" "context" "suite" "fdescribe" "xdescribe"))
