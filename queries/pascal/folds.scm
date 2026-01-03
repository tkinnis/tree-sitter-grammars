; NOTE: Pascal's if/ifElse span the entire if-else chain.
; Folding these will hide else clauses. This is a known limitation as Pascal
; uses begin...end blocks which aren't separately captured in the grammar.
[
  (interface)
  (implementation)
  (initialization)
  (finalization)
  (if)
  (ifElse)
  (while)
  (repeat)
  (for)
  (foreach)
  (try)
  (case)
  (caseCase)
  (asm)
  (with)
  (declVar)
  (declConst)
  (declEnum)
  (declProcRef)
  (declExports)
  (declProcRef)
  (declType)
  (defProc)
  (declField)
  (declProp)
  (comment)
] @fold

(interface
  (declProc) @fold)
