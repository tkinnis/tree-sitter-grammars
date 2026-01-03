[
  (import_from_statement)
  (generator_expression)
  (list_comprehension)
  (set_comprehension)
  (dictionary_comprehension)
  (tuple_pattern)
  (list_pattern)
  (binary_operator)
  (lambda)
  (concatenated_string)
] @indent.begin

((list) @indent.align

)

((dictionary) @indent.align

)

((set) @indent.align

)

((parenthesized_expression) @indent.align
  (#set! "scope" "all"))

((for_statement) @indent.begin
)

((if_statement) @indent.begin
)

((while_statement) @indent.begin
)

((try_statement) @indent.begin
)

(ERROR
  "try"
  .
  ":"
) @indent.begin

; Commented out: causes TSQueryErrorCapture (type 5) at offset 645
; This nested ERROR pattern with multiple captures is not supported by our tree-sitter bindings
; TODO: investigate tree-sitter version compatibility
; (ERROR
;   "try"
;   .
;   ":"
;   (ERROR
;     (block
;       (expression_statement
;         (identifier) @_except) @indent.branch))
;   (#match? @_except "^except$"))

((function_definition) @indent.begin
)

((class_definition) @indent.begin
)

((with_statement) @indent.begin
)

((match_statement) @indent.begin
)

((case_clause) @indent.begin
)

; if (cond1
;     or cond2
;         or cond3):
;     pass
;
(if_statement
  condition: (parenthesized_expression) @indent.align
  (#match? @indent.align "^\\([^\n]+"))

; while (
;     cond1
;     or cond2
;         or cond3):
;     pass
;
(while_statement
  condition: (parenthesized_expression) @indent.align
  (#match? @indent.align "[^\n ]\\)$"))

; if (
;     cond1
;     or cond2
;         or cond3):
;     pass
;
(if_statement
  condition: (parenthesized_expression) @indent.align
  (#match? @indent.align "[^\n ]\\)$"))

(ERROR
  "(" @indent.align
  .
  (_))

((argument_list) @indent.align
  (#set! "scope" "all"))

((parameters) @indent.align
  (#set! "scope" "all"))

((parameters) @indent.align
  (#match? @indent.align "[^\n ]\\)$"))

((tuple) @indent.align
  (#set! "scope" "all"))

(ERROR
  "[" @indent.align

.
  (_))

(ERROR
  "{" @indent.align

.
  (_))

[
  (break_statement)
  (continue_statement)
] @indent.dedent

(ERROR
  (_) @indent.branch
  ":"
  .
  (#match? @indent.branch "^else"))

(ERROR
  (_) @indent.branch @indent.dedent
  ":"
  .
  (#match? @indent.branch "^elif"))

(generator_expression
  ")" @indent.end)

(list_comprehension
  "]" @indent.end)

(set_comprehension
  "}" @indent.end)

(dictionary_comprehension
  "}" @indent.end)

(tuple_pattern
  ")" @indent.end)

(list_pattern
  "]" @indent.end)

(return_statement
  [
    (_) @indent.end
    (_
      [
        (_)
        ")"
        "}"
        "]"
      ] @indent.end .)
    (attribute
      attribute: (_) @indent.end)
    (call
      arguments: (_
        ")" @indent.end))
    "return" @indent.end
  ] .)

; Closing delimiters mark scope boundaries but don't dedent
[
  ")"
  "]"
  "}"
] @indent.end

; Clause keywords dedent to align with statement
[
  (elif_clause)
  (else_clause)
  (except_clause)
  (finally_clause)
] @indent.branch

(string) @indent.auto
