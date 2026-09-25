; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, runtime/queries/xml/injections.scm @ 692b051b09935653befdb8f7ba8afdb640adf17b, Apache-2.0.
; Modified in tree-sitter-grammars.

((Comment) @injection.content
  (#set! injection.language "comment"))

; SVG style
((element
  (STag
    (Name) @_name)
  (content) @injection.content)
  (#match? @_name "^style$")

)

; SVG script
((element
  (STag
    (Name) @_name)
  (content) @injection.content)
  (#match? @_name "^script$")

)

; phpMyAdmin dump
((element
  (STag
    (Name) @_name)
  (content) @injection.content)
  (#match? @_name "^pma:table$")

)
