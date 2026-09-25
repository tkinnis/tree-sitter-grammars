; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, runtime/queries/python/folds.scm @ 692b051b09935653befdb8f7ba8afdb640adf17b, Apache-2.0.
; Modified in tree-sitter-grammars.

; NOTE: Python's if_statement spans the entire if-elif-else chain.
; Folding if_statement will hide elif/else clauses. This is a known limitation
; due to Python's indentation-based blocks - there's no separate block node
; that can be folded independently.
[
  (function_definition)
  (class_definition)
  (while_statement)
  (for_statement)
  (if_statement)
  (with_statement)
  (try_statement)
  (match_statement)
  (import_from_statement)
  (parameters)
  (argument_list)
  (parenthesized_expression)
  (generator_expression)
  (list_comprehension)
  (set_comprehension)
  (dictionary_comprehension)
  (tuple)
  (list)
  (set)
  (dictionary)
  (string)
] @fold

[
  (import_statement)
  (import_from_statement)
]+ @fold
