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
