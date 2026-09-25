; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, queries/pascal/locals.scm @ 5b90ea2abaa4303b9205b5c9002a8cdd0acd11a5, Apache-2.0.
; Taken from https://github.com/Isopod/tree-sitter-pascal, queries/locals.scm @ 22fb8f8fe5e6822266e82794a1d19444f9f3879e, MIT.
; Unchanged.


(root)                                   @local.scope

(defProc)                                @local.scope
(lambda)                                 @local.scope
(interface   (declProc)                  @local.scope)
(declSection (declProc)                  @local.scope)
(declClass   (declProc)                  @local.scope)
(declHelper  (declProc)                  @local.scope)
(declProcRef)                            @local.scope

(exceptionHandler)                       @local.scope
(exceptionHandler variable: (identifier) @local.definition)

(declArg          name: (identifier)     @local.definition)
(declVar          name: (identifier)     @local.definition)
(declConst        name: (identifier)     @local.definition)
(declLabel        name: (identifier)     @local.definition)
(genericArg       name: (identifier)     @local.definition)
(declEnumValue    name: (identifier)     @local.definition)
(declType         name: (identifier)     @local.definition)
(declType         name: (genericTpl entity: (identifier)     @local.definition))

(declProc         name: (identifier)     @local.definition)

(identifier)                             @local.reference
