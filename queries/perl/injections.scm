; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, queries/perl/injections.scm @ 57a8acf0c4ed5e7f6dda83c3f9b073f8a99a70f9, Apache-2.0.
; Taken from https://github.com/tree-sitter-perl/tree-sitter-perl, queries/injections.scm @ ad5b6f3967e46423cda1dbef3823c9cd031a5c6b, MIT.
; Unchanged.

; an injections.scm file for nvim-treesitter
((comment) @injection.content
 (#set! injection.language "comment"))
 
((pod) @injection.content
 (#set! injection.language "pod"))

((substitution_regexp
  (replacement) @injection.content
  (substitution_regexp_modifiers) @_modifiers)
    ; match if there's a single `e` in the modifiers list
  (#match? @_modifiers "e")
  (#not-match? @_modifiers "e.*e")
  (#set! injection.language "perl"))
