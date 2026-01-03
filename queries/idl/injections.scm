((comment) @injection.content
  (#match? @injection.content "/[*\/][!*\/]<?[^a-zA-Z]")
)

((comment) @injection.content
  (#not-lua-match? @injection.content "/[*\/][!*\/]<?[^a-zA-Z]")
  (#not-lua-match? @injection.content "//@[a-zA-Z]")
)
