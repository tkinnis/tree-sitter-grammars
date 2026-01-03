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
