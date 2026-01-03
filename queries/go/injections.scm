((comment) @injection.content
)

(call_expression
  (selector_expression) @_function
  (#match? @_function "^regexp\.Match$")
  (argument_list
    .
    [
      (raw_string_literal
        (raw_string_literal_content) @injection.content)
      (interpreted_string_literal
        (interpreted_string_literal_content) @injection.content)
    ]
))

(call_expression
  (selector_expression) @_function
  (#match? @_function "^regexp\.MatchReader$")
  (argument_list
    .
    [
      (raw_string_literal
        (raw_string_literal_content) @injection.content)
      (interpreted_string_literal
        (interpreted_string_literal_content) @injection.content)
    ]
))

(call_expression
  (selector_expression) @_function
  (#match? @_function "^regexp\.MatchString$")
  (argument_list
    .
    [
      (raw_string_literal
        (raw_string_literal_content) @injection.content)
      (interpreted_string_literal
        (interpreted_string_literal_content) @injection.content)
    ]
))

(call_expression
  (selector_expression) @_function
  (#match? @_function "^regexp\.Compile$")
  (argument_list
    .
    [
      (raw_string_literal
        (raw_string_literal_content) @injection.content)
      (interpreted_string_literal
        (interpreted_string_literal_content) @injection.content)
    ]
))

(call_expression
  (selector_expression) @_function
  (#match? @_function "^regexp\.CompilePOSIX$")
  (argument_list
    .
    [
      (raw_string_literal
        (raw_string_literal_content) @injection.content)
      (interpreted_string_literal
        (interpreted_string_literal_content) @injection.content)
    ]
))

(call_expression
  (selector_expression) @_function
  (#match? @_function "^regexp\.MustCompile$")
  (argument_list
    .
    [
      (raw_string_literal
        (raw_string_literal_content) @injection.content)
      (interpreted_string_literal
        (interpreted_string_literal_content) @injection.content)
    ]
))

(call_expression
  (selector_expression) @_function
  (#match? @_function "^regexp\.MustCompilePOSIX$")
  (argument_list
    .
    [
      (raw_string_literal
        (raw_string_literal_content) @injection.content)
      (interpreted_string_literal
        (interpreted_string_literal_content) @injection.content)
    ]
))

((comment) @injection.content
  (#match? @injection.content "/\\*!([a-zA-Z]+:)?re2c")
)

((call_expression
  function: (selector_expression
    field: (field_identifier) @_method)
  arguments: (argument_list
    .
    (interpreted_string_literal
      (interpreted_string_literal_content) @injection.content)))
  (#match? @_method "^Printf$")
)

((call_expression
  function: (selector_expression
    field: (field_identifier) @_method)
  arguments: (argument_list
    .
    (interpreted_string_literal
      (interpreted_string_literal_content) @injection.content)))
  (#match? @_method "^Sprintf$")
)

((call_expression
  function: (selector_expression
    field: (field_identifier) @_method)
  arguments: (argument_list
    .
    (interpreted_string_literal
      (interpreted_string_literal_content) @injection.content)))
  (#match? @_method "^Fatalf$")
)

((call_expression
  function: (selector_expression
    field: (field_identifier) @_method)
  arguments: (argument_list
    .
    (interpreted_string_literal
      (interpreted_string_literal_content) @injection.content)))
  (#match? @_method "^Scanf$")
)

((call_expression
  function: (selector_expression
    field: (field_identifier) @_method)
  arguments: (argument_list
    .
    (interpreted_string_literal
      (interpreted_string_literal_content) @injection.content)))
  (#match? @_method "^Errorf$")
)

((call_expression
  function: (selector_expression
    field: (field_identifier) @_method)
  arguments: (argument_list
    .
    (interpreted_string_literal
      (interpreted_string_literal_content) @injection.content)))
  (#match? @_method "^Skipf$")
)

((call_expression
  function: (selector_expression
    field: (field_identifier) @_method)
  arguments: (argument_list
    .
    (interpreted_string_literal
      (interpreted_string_literal_content) @injection.content)))
  (#match? @_method "^Logf$")
)

((call_expression
  function: (selector_expression
    field: (field_identifier) @_method)
  arguments: (argument_list
    (_)
    .
    (interpreted_string_literal
      (interpreted_string_literal_content) @injection.content)))
  (#match? @_method "^Fprintf$")
)

((call_expression
  function: (selector_expression
    field: (field_identifier) @_method)
  arguments: (argument_list
    (_)
    .
    (interpreted_string_literal
      (interpreted_string_literal_content) @injection.content)))
  (#match? @_method "^Fscanf$")
)

((call_expression
  function: (selector_expression
    field: (field_identifier) @_method)
  arguments: (argument_list
    (_)
    .
    (interpreted_string_literal
      (interpreted_string_literal_content) @injection.content)))
  (#match? @_method "^Appendf$")
)

((call_expression
  function: (selector_expression
    field: (field_identifier) @_method)
  arguments: (argument_list
    (_)
    .
    (interpreted_string_literal
      (interpreted_string_literal_content) @injection.content)))
  (#match? @_method "^Sscanf$")
)
