; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, runtime/queries/python/injections.scm @ 692b051b09935653befdb8f7ba8afdb640adf17b, Apache-2.0.
; Modified in tree-sitter-grammars.

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
