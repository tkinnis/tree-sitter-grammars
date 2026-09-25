; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, runtime/queries/ada/folds.scm @ 692b051b09935653befdb8f7ba8afdb640adf17b, Apache-2.0.
; Modified in tree-sitter-grammars.

; Support for folding in Ada
; NOTE: Ada's if_statement spans the entire if-elsif-else chain.
; Folding if_statement will hide elsif/else clauses. This is a known limitation.
[
  (package_declaration)
  (generic_package_declaration)
  (package_body)
  (subprogram_body)
  (block_statement)
  (if_statement)
  (loop_statement)
  (gnatprep_declarative_if_statement)
  (gnatprep_if_statement)
] @fold
