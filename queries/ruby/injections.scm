((comment) @injection.content
)

(heredoc_body
  (heredoc_content) @injection.content
  (heredoc_end) @injection.language
  (#downcase! @injection.language))

(regex
  (string_content) @injection.content
)

((call
  receiver: (identifier) @_receiver
  method: (identifier) @_method
  arguments: (argument_list
    (pair
      key: (hash_key_symbol)
      value: (string
        (string_content) @injection.content))))
  (#match? @_receiver "^binding$")
  (#match? @_method "^b$")
)

((call
  receiver: (identifier) @_receiver
  method: (identifier) @_method
  arguments: (argument_list
    (pair
      key: (hash_key_symbol)
      value: (string
        (string_content) @injection.content))))
  (#match? @_receiver "^binding$")
  (#match? @_method "^break$")
)
