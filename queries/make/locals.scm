; Scopes
;-------

(makefile) @local.scope

(rule) @local.scope

; Definitions
;------------

(variable_assignment
  name: (word) @local.definition.var)

(rule
  (targets
    (word) @local.definition.var))

; References
;-----------

(variable_reference
  (word) @local.reference)

(automatic_variable) @local.reference
