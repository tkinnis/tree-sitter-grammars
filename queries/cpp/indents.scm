[
  (compound_statement)
  (field_declaration_list)
  (case_statement)
  (enumerator_list)
  (compound_literal_expression)
  (initializer_list)
  (init_declarator)
] @indent.begin

; With current indent logic, if we capture expression_statement with @indent.begin
; It will be affected by _parent_ node with error subnodes deep down the tree
; So narrow indent capture to check for error inside expression statement only,
(expression_statement
  (_) @indent.begin
  ";" @indent.end)

(ERROR
  "for"
  "(" @indent.begin
  ";"
  ";"
  ")" @indent.end)

((for_statement
  body: (_) @_body) @indent.begin
  (#not-kind-eq? @_body "compound_statement"))

(while_statement
  condition: (_) @indent.begin)

((while_statement
  body: (_) @_body) @indent.begin
  (#not-kind-eq? @_body "compound_statement"))

((if_statement)
  .
  (ERROR
    "else" @indent.begin))

(if_statement
  condition: (_) @indent.begin)

; Supports if without braces (but not both if-else without braces)
(if_statement
  consequence: (_
    ";" @indent.end) @_consequence
  (#not-kind-eq? @_consequence "compound_statement")
  alternative: (else_clause
    "else" @indent.branch
    [
      (if_statement
        (compound_statement) @indent.dedent)? @indent.dedent
      (compound_statement)? @indent.dedent
      (_)? @indent.dedent
    ])?) @indent.begin

(else_clause
  (_
    .
    "{" @indent.branch))

(compound_statement
  "}" @indent.end)

; Closing brace dedents the line
"}" @indent.dedent

; Closing paren marks scope boundary but doesn't dedent
")" @indent.end

; Labels dedent to align with block
(statement_identifier) @indent.branch

[
  "#define"
  "#ifdef"
  "#ifndef"
  "#elif"
  "#if"
  "#else"
  "#endif"
] @indent.zero

[
  (preproc_arg)
  (string_literal)
] @indent.ignore

((ERROR
  (parameter_declaration)) @indent.align
  (#set! "scope" "all"))

([
  (argument_list)
  (parameter_list)
] @indent.align
  (#set! "scope" "all"))

(comment) @indent.auto
; inherits: c

(condition_clause) @indent.begin

((field_initializer_list) @indent.begin
)

(access_specifier) @indent.branch
