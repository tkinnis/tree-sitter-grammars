; Match (define name value)
(list
  . (symbol) @_define
  (#eq? @_define "define")
  (symbol) @name) @definition.function

; Match (define (name args...) body)
(list
  . (symbol) @_define
  (#eq? @_define "define")
  (list
    . (symbol) @name)) @definition.function
