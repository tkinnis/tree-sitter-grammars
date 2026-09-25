; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, runtime/queries/ruby/folds.scm @ 692b051b09935653befdb8f7ba8afdb640adf17b, Apache-2.0.
; Modified in tree-sitter-grammars.

; Removed (if) - fold (then) instead to keep else/elsif visible
[
  (method)
  (singleton_method)
  (class)
  (module)
  (then)
  (elsif)
  (else)
  (case)
  (do_block)
  (singleton_class)
  (lambda)
] @fold
