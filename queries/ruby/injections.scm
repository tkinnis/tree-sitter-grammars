; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, runtime/queries/ruby/injections.scm @ 692b051b09935653befdb8f7ba8afdb640adf17b, Apache-2.0.
; Modified in tree-sitter-grammars.

((comment) @injection.content
  (#set! injection.language "comment"))

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
