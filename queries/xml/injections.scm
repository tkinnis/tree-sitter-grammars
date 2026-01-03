((Comment) @injection.content
)

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
