(create_table
  (object_reference
    name: (identifier) @name)) @definition.table

(create_view
  (object_reference
    name: (identifier) @name)) @definition.view

(create_index
  column: (identifier) @name) @definition.index

(create_function
  (object_reference
    name: (identifier) @name)) @definition.function

(column_definition
  name: (identifier) @name) @definition.column
