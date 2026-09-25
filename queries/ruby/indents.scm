; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, runtime/queries/ruby/indents.scm @ 692b051b09935653befdb8f7ba8afdb640adf17b, Apache-2.0.
; Modified in tree-sitter-grammars.

[
  (class)
  (singleton_class)
  (method)
  (singleton_method)
  (module)
  (call)
  (if)
  (block)
  (do_block)
  (hash)
  (array)
  (argument_list)
  (case)
  (while)
  (until)
  (for)
  (begin)
  (unless)
  (assignment)
  (parenthesized_statements)
] @indent.begin

[
  "end"
  ")"
  "}"
  "]"
] @indent.end

; Keywords that dedent to align with block opener
[
  "end"
  (when)
  (elsif)
  (else)
  (rescue)
  (ensure)
] @indent.branch

(comment) @indent.ignore
