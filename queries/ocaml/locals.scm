; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, queries/ocaml/locals.scm @ 7be8e6ca5c5dfe8414641c9d33605db31418debc, Apache-2.0.
; Taken from https://github.com/tree-sitter/tree-sitter-ocaml, queries/locals.scm @ e0e760fe206e5a860687dd5f14e6911c515e5c70, MIT.
; Unchanged.

; Scopes
;-------

[
  (let_binding)
  (class_binding)
  (class_function)
  (method_definition)
  (fun_expression)
  (object_expression)
  (for_expression)
  (match_case)
  (attribute_payload)
] @local.scope

; Definitions
;------------

(value_pattern) @local.definition

; References
;-----------

(value_path . (value_name) @local.reference)
