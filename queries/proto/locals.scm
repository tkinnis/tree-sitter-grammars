; Scopes
;-------

(message_body) @local.scope

(enum_body) @local.scope

(service) @local.scope

; Definitions
;------------

(message
  (message_name
    (identifier) @local.definition.type))

(enum
  (enum_name
    (identifier) @local.definition.type))

(service
  (service_name
    (identifier) @local.definition.type))

(rpc
  (rpc_name
    (identifier) @local.definition.method))

(field
  (identifier) @local.definition.field)

(enum_field
  (identifier) @local.definition.constant)

; References
;-----------

(message_or_enum_type
  (identifier) @local.reference)
