";" @indent.end

; Closing brace dedents
"}" @indent.dedent

(definition) @indent.begin

[
  (preproc_define)
  (preproc_include)
] @indent.ignore
