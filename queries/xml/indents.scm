; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, queries/xml/indents.scm @ 5b3dd8cff1064db583ddd3edd314e94a02ea1bef, Apache-2.0.
; Modified in tree-sitter-grammars.

(element) @indent.begin

[
  (Attribute)
  (AttlistDecl)
  (contentspec)
] @indent.align

; End tags dedent to match their opening element
(ETag) @indent.dedent

(doctypedecl) @indent.ignore

[
  (Comment)
  (ERROR)
] @indent.auto
