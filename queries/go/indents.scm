; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, runtime/queries/go/indents.scm @ 692b051b09935653befdb8f7ba8afdb640adf17b, Apache-2.0.
; Modified in tree-sitter-grammars.

[
  (import_declaration)
  (const_declaration)
  (var_declaration)
  (type_declaration)
  (func_literal)
  (literal_value)
  (expression_case)
  (communication_case)
  (type_case)
  (default_case)
  (block)
  (call_expression)
  (parameter_list)
  (field_declaration_list)
  (interface_type)
] @indent.begin

(literal_value
  "}" @indent.branch)

(block
  "}" @indent.branch)

(field_declaration_list
  "}" @indent.branch)

(interface_type
  "}" @indent.branch)

; Closing parens mark scope end but don't dedent (avoid issues with single-line signatures)
(const_declaration
  ")" @indent.end)

(import_spec_list
  ")" @indent.end)

(var_spec_list
  ")" @indent.end)

(parameter_list
  ")" @indent.end)

[
  "}"
  ")"
] @indent.end

(comment) @indent.ignore
