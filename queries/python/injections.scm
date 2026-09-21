(call
  function: (attribute
    object: (identifier) @_re)
  arguments: (argument_list
    .
    (string
      (string_content) @injection.content))
  (#match? @_re "^re$")
)

((binary_operator
  left: (string
    (string_content) @injection.content)
  operator: "%")
)

((comment) @injection.content
  (#set! injection.language "comment"))
