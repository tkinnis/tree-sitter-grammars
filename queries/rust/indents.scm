; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, queries/rust/indents.scm @ 1b050206e490a4146cdf25c7b38969c1711b5620, Apache-2.0.
; Modified in tree-sitter-grammars.

[
  (mod_item)
  (struct_item)
  (enum_item)
  (impl_item)
  (struct_expression)
  (struct_pattern)
  (tuple_struct_pattern)
  (tuple_expression)
  (tuple_type)
  (tuple_pattern)
  (match_block)
  (call_expression)
  (assignment_expression)
  (arguments)
  (block)
  (where_clause)
  (use_list)
  (array_expression)
  (ordered_field_declaration_list)
  (field_declaration_list)
  (enum_variant_list)
  (parameters)
  (token_tree)
  (token_repetition)
  (macro_definition)
] @indent.begin

; Typing in "(" inside macro definitions breaks the tree entirely
; Making macro_definition becoming errors
; Offset this by adding back one indent for start of macro rules
(ERROR
  .
  "macro_rules!"
  [
    "("
    "{"
    "["
  ] @indent.begin

)

(macro_definition
  [
    ")"
    "}"
    "]"
  ] @indent.end)

(trait_item
  body: (_) @indent.begin)

(string_literal
  (escape_sequence)) @indent.begin

(block
  "}" @indent.end)

(enum_item
  body: (enum_variant_list
    "}" @indent.end))

(impl_item
  body: (declaration_list
    "}" @indent.end))

(match_expression
  body: (match_block
    "}" @indent.end))

(mod_item
  body: (declaration_list
    "}" @indent.end))

(struct_item
  body: (field_declaration_list
    "}" @indent.end))

(struct_expression
  body: (field_initializer_list
    "}" @indent.end))

(struct_pattern
  "}" @indent.end)

(tuple_struct_pattern
  ")" @indent.end)

(tuple_type
  ")" @indent.end)

(tuple_pattern
  ")" @indent.end)

(trait_item
  body: (declaration_list
    "}" @indent.end))

(impl_item
  (where_clause) @indent.dedent)

; Closing brace dedents the line
"}" @indent.dedent

; Closing parens/brackets mark scope boundaries but don't dedent
[
  ")"
  "]"
] @indent.end

; where clause dedents to align with impl/fn
"where" @indent.branch

(impl_item
  (declaration_list) @indent.branch)

[
  (line_comment)
  (string_literal)
] @indent.ignore

(raw_string_literal) @indent.auto
