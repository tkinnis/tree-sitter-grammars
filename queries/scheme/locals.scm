; Scopes
;-------

(program) @local.scope

; Define forms create scopes
((list
  .
  (symbol) @_define
  .
  (list)
  (#eq? @_define "define")) @local.scope)

; Lambda forms create scopes
((list
  .
  (symbol) @_lambda
  (#eq? @_lambda "lambda")) @local.scope)

; Let forms create scopes
((list
  .
  (symbol) @_let
  (#match? @_let "^let[*]?$")) @local.scope)

; Definitions
;------------

; (define name value) - variable definition
((list
  .
  (symbol) @_define
  .
  (symbol) @local.definition.var
  (#eq? @_define "define"))
  (#not-match? @local.definition.var "^[()]"))

; (define (name params...) body) - function definition
((list
  .
  (symbol) @_define
  .
  (list
    .
    (symbol) @local.definition.function)
  (#eq? @_define "define"))
  (#not-match? @local.definition.function "^[()]"))

; Function parameters in (define (name params) body)
((list
  .
  (symbol) @_define
  .
  (list
    (symbol)
    (symbol) @local.definition.parameter)
  (#eq? @_define "define"))
  (#not-match? @local.definition.parameter "^[()]"))

; Lambda parameters
((list
  .
  (symbol) @_lambda
  .
  (list
    (symbol) @local.definition.parameter)
  (#eq? @_lambda "lambda"))
  (#not-match? @local.definition.parameter "^[()]"))

; Let bindings
((list
  .
  (symbol) @_let
  .
  (list
    (list
      .
      (symbol) @local.definition.var))
  (#match? @_let "^let[*]?$"))
  (#not-match? @local.definition.var "^[()]"))

; References
;-----------

(symbol) @local.reference
