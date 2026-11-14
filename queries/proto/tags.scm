(message
  (message_name
    (identifier) @name)) @definition.class

(enum
  (enum_name
    (identifier) @name)) @definition.enum

(enum_field
  (identifier) @name) @definition.enum_member

(service
  (service_name
    (identifier) @name)) @definition.interface

(rpc
  (rpc_name
    (identifier) @name)) @definition.method

(field
  (type)
  (identifier) @name) @definition.property
