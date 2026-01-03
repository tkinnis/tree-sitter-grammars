(function_definition
  name: (identifier) @name) @definition.function

(class_definition
  name: (identifier) @name) @definition.class

(class_definition
  body: (block
    (function_definition
      name: (identifier) @name))) @definition.method

(assignment
  left: (identifier) @name) @definition.variable

(assignment
  left: (pattern_list
    (identifier) @name)) @definition.variable

(parameters
  (identifier) @name) @definition.parameter

(typed_parameter
  (identifier) @name) @definition.parameter

(typed_default_parameter
  (identifier) @name) @definition.parameter
