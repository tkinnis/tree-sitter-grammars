; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, runtime/queries/jsx/indents.scm @ 692b051b09935653befdb8f7ba8afdb640adf17b, Apache-2.0.
; Unchanged.

[
  (jsx_element)
  (jsx_self_closing_element)
  (jsx_expression)
] @indent.begin

(jsx_closing_element
  ">" @indent.end)

(jsx_self_closing_element
  "/>" @indent.end)

[
  (jsx_closing_element)
  ">"
] @indent.branch

; <button
; />
(jsx_self_closing_element
  "/>" @indent.branch)
