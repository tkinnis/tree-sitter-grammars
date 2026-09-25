; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, runtime/queries/kotlin/injections.scm @ 692b051b09935653befdb8f7ba8afdb640adf17b, Apache-2.0.
; Modified in tree-sitter-grammars.

([
  (line_comment)
  (multiline_comment)
] @injection.content
  (#set! injection.language "comment"))

; There are 3 ways to define a regex
;    - "[abc]?".toRegex()
(call_expression
  (navigation_expression
    ((string_literal) @injection.content
)
    (navigation_suffix
      ((simple_identifier) @_function
        (#match? @_function "^toRegex$")))))

;    - Regex("[abc]?")
(call_expression
  ((simple_identifier) @_function
    (#match? @_function "^Regex$"))
  (call_suffix
    (value_arguments
      (value_argument
        (string_literal) @injection.content
))))

;    - Regex.fromLiteral("[abc]?")
(call_expression
  (navigation_expression
    ((simple_identifier) @_class
      (#match? @_class "^Regex$"))
    (navigation_suffix
      ((simple_identifier) @_function
        (#match? @_function "^fromLiteral$"))))
  (call_suffix
    (value_arguments
      (value_argument
        (string_literal) @injection.content
))))

; "pi = %.2f".format(3.14159)
((call_expression
  (navigation_expression
    (string_literal) @injection.content
    (navigation_suffix
      (simple_identifier) @_method)))
  (#match? @_method "^format$")
)
