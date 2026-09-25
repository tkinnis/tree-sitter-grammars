; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, queries/lua/injections.scm @ c80715f883b8c7963782973b23297c5dec7924be, Apache-2.0.
; Modified in tree-sitter-grammars.

((function_call
  name: [
    (identifier) @_cdef_identifier
    (_ _ (identifier) @_cdef_identifier)
  ]
  arguments: (arguments (string content: _ @injection.content
    (#set! injection.language "c"))))
  (#eq? @_cdef_identifier "cdef"))

((comment) @injection.content
  (#set! injection.language "comment"))
