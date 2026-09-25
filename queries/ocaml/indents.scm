; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, runtime/queries/ocaml/indents.scm @ 692b051b09935653befdb8f7ba8afdb640adf17b, Apache-2.0.
; Modified in tree-sitter-grammars.

; format-ignore
[ 
  (let_binding)                 ; let = ...
  (type_binding)

  (external)
  (record_declaration)          ; { foo: bar ... }
  (structure)                   ; struct ... end
  (signature)                   ; sig ... end
  (value_specification)         ; val x: bar

  (do_clause)                   ; do ... done
  (match_case)

  (field_expression)
  (application_expression)
  (parenthesized_expression)    ; ( ... )
  (record_expression)           ; { foo = bar ... }
  (list_expression)             ; [...;...]
  (try_expression)              ; try ... with
] @indent.begin

; handle if-else if-else case
(if_expression
  condition: (_) @indent.begin)

(then_clause) @indent.begin

((else_clause
  (_) @_not_if) @indent.begin
  (#not-kind-eq? @_not_if "if_expression"))

((parameter) @indent.begin
)

(_
  (ERROR) @indent.begin
)

(ERROR
  "|" @indent.begin
)

(try_expression
  "with" @indent.branch
  [
    (match_case) @indent.dedent
    (match_case
      [
        (parenthesized_expression)
        (list_expression)
      ] @indent.dedent)
  ])

"}" @indent.branch @indent.end

(list_expression
  "]" @indent.branch)

(parenthesized_expression
  ")" @indent.branch)

";;" @indent.end

(do_clause
  "done" @indent.end @indent.branch)

(structure
  "end" @indent.end @indent.branch)

(signature
  "end" @indent.end @indent.branch)

[
  (string)
  (comment)
] @indent.auto
