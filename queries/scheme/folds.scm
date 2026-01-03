; Scheme is homoiconic - all expressions are lists.
; The grammar doesn't distinguish if, define, lambda, etc. - they're all lists.
; Fold any list (if, cond, define, lambda, let, etc.)
(list) @fold
