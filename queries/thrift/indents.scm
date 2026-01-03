(definition) @indent.begin

((parameters
  (parameter)) @indent.align
  (#set! "scope" "all"))

; Closing brace dedents
"}" @indent.dedent

; Closing delimiters mark scope boundaries but don't dedent
[
  ")"
] @indent.end

[
  (ERROR)
  (comment)
] @indent.auto
