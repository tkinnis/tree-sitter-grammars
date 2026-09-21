([
  (block_comment)
  (line_comment)
] @injection.content
  (#set! injection.language "comment"))

((block_comment) @injection.content
  (#match? @injection.content "/[*][*][%s]")
)

; markdown-style javadocs https://openjdk.org/jeps/467
((line_comment) @injection.content
  (#match? @injection.content "^///%s")
)

((method_invocation
  name: (identifier) @_method
  arguments: (argument_list
    .
    (string_literal
      .
      (_) @injection.content)))
  (#match? @_method "^format$")
)

((method_invocation
  name: (identifier) @_method
  arguments: (argument_list
    .
    (string_literal
      .
      (_) @injection.content)))
  (#match? @_method "^printf$")
)

((method_invocation
  object: (string_literal
    (string_fragment) @injection.content)
  name: (identifier) @_method)
  (#match? @_method "^formatted$")
)
