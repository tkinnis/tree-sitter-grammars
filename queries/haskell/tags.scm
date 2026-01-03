(function
  name: (variable) @name) @definition.function

(signature
  name: (variable) @name) @definition.function

(type_synomym
  name: (name) @name) @definition.type

(newtype
  name: (name) @name) @definition.type

(data_type
  name: (name) @name) @definition.type

(data_constructor
  constructor: (prefix
    name: (constructor) @name)) @definition.constructor

(class
  name: (name) @name) @definition.class
