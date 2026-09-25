; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, runtime/queries/pascal/indents.scm @ 692b051b09935653befdb8f7ba8afdb640adf17b, Apache-2.0.
; Modified in tree-sitter-grammars.

[
  (statement)
  (declVars)
  (declConsts)
  (declTypes)
  (declProc)
  (declArgs)
  (declUses)
  (declClass)
  (exprArgs)
  (exprSubscript)
  (exprBrackets)
  (exprParens)
  (recInitializer)
  (arrInitializer)
  (defaultValue)
] @indent.begin

(defProc
  (block) @indent.begin)

; Closing parens/brackets mark scope boundaries but don't dedent
[
  "]"
  ")"
] @indent.end

; Keywords dedent to align with block opener
[
  (kEnd)
  (kFinally)
  (kDo)
  (kUntil)
  (kExcept)
  (kElse)
  (kThen)
  (declSection)
] @indent.branch
