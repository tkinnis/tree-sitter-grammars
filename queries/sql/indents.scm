; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, runtime/queries/sql/indents.scm @ 692b051b09935653befdb8f7ba8afdb640adf17b, Apache-2.0.
; Unchanged.

[
  (select)
  (cte)
  (column_definitions)
  (case)
  (subquery)
  (insert)
  (when_clause)
] @indent.begin

(block
  (keyword_begin)) @indent.begin

(column_definitions
  ")" @indent.branch)

(subquery
  ")" @indent.branch)

(cte
  ")" @indent.branch)

[
  (keyword_end)
  (keyword_values)
  (keyword_into)
] @indent.branch

(keyword_end) @indent.end
