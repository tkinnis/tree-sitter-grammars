; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, runtime/queries/c_sharp/folds.scm @ 692b051b09935653befdb8f7ba8afdb640adf17b, Apache-2.0.
; Unchanged.

body: [
  (declaration_list)
  (switch_body)
  (enum_member_declaration_list)
] @fold

accessors: (accessor_list) @fold

initializer: (initializer_expression) @fold

[
  (block)
  (preproc_if)
  (preproc_elif)
  (preproc_else)
  (using_directive)+
] @fold
