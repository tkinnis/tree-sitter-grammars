; Scopes
;-------

(block) @local.scope

(subroutine_declaration_statement) @local.scope

; Definitions
;------------

(subroutine_declaration_statement
  name: (bareword) @local.definition.function)

(variable_declaration
  variable: (scalar
    (varname) @local.definition.var))

(variable_declaration
  variables: (scalar
    (varname) @local.definition.var))

; References
;-----------

(scalar
  (varname) @local.reference)

(function) @local.reference
