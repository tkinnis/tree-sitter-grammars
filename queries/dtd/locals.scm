; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, runtime/queries/dtd/locals.scm @ 692b051b09935653befdb8f7ba8afdb640adf17b, Apache-2.0.
; Unchanged.

(elementdecl
  (Name) @local.definition.type)

(elementdecl
  (contentspec
    (children
      (Name) @local.reference)))

(AttlistDecl
  .
  (Name) @local.reference)
