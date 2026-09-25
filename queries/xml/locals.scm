; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, runtime/queries/xml/locals.scm @ 692b051b09935653befdb8f7ba8afdb640adf17b, Apache-2.0.
; Unchanged.

; tags
(elementdecl
  (Name) @local.definition.type)

(elementdecl
  (contentspec
    (children
      (Name) @local.reference)))

(AttlistDecl
  .
  (Name) @local.reference)

(STag
  (Name) @local.reference)

(ETag
  (Name) @local.reference)

(EmptyElemTag
  (Name) @local.reference)

; attributes
(AttDef
  (Name) @local.definition.field)

(Attribute
  (Name) @local.reference)

; entities
(GEDecl
  (Name) @local.definition.macro)

(EntityRef
  (Name) @local.reference)
