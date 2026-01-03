; Common Lisp is homoiconic - most expressions are lists.
; Fold any list (defun, let, loop, cond, if, etc.)
(list_lit) @fold

; Also fold vectors and specialized forms
[
  (vec_lit)
  (defun)
  (loop_macro)
] @fold
