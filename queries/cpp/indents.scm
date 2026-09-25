; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, runtime/queries/cpp/indents.scm @ 692b051b09935653befdb8f7ba8afdb640adf17b, Apache-2.0.
; Modified in tree-sitter-grammars.

; inherits: c

(condition_clause) @indent.begin

((field_initializer_list) @indent.begin
)

(access_specifier) @indent.branch
