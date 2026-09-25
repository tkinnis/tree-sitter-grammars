; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, runtime/queries/bash/locals.scm @ 692b051b09935653befdb8f7ba8afdb640adf17b, Apache-2.0.
; Unchanged.

; Scopes
(function_definition) @local.scope

; Definitions
(variable_assignment
  name: (variable_name) @local.definition.var)

(function_definition
  name: (word) @local.definition.function)

; References
(variable_name) @local.reference

(word) @local.reference
