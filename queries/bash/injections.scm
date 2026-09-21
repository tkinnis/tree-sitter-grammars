((comment) @injection.content
  (#set! injection.language "comment"))

((heredoc_redirect
  (heredoc_body) @injection.content
  (heredoc_end) @injection.language)
  (#downcase! @injection.language))

; printf 'format'
((command
  name: (command_name) @_command
  .
  argument: [
    (string) @injection.content
    (concatenation
      (string) @injection.content)
    (raw_string) @injection.content
    (concatenation
      (raw_string) @injection.content)
  ])
  (#match? @_command "^printf$")
)

; printf -v var 'format'
((command
  name: (command_name) @_command
  argument: (word) @_arg
  .
  (_)
  .
  argument: [
    (string) @injection.content
    (concatenation
      (string) @injection.content)
    (raw_string) @injection.content
    (concatenation
      (raw_string) @injection.content)
  ])
  (#match? @_command "^printf$")
  (#match? @_arg "^-v$")
)

; printf -- 'format'
((command
  name: (command_name) @_command
  argument: (word) @_arg
  .
  argument: [
    (string) @injection.content
    (concatenation
      (string) @injection.content)
    (raw_string) @injection.content
    (concatenation
      (raw_string) @injection.content)
  ])
  (#match? @_command "^printf$")
  (#match? @_arg "^--$")
)

((command
  name: (command_name) @_command
  .
  argument: [
    (string)
    (raw_string)
  ] @injection.content)
  (#match? @_command "^bind$")
)
