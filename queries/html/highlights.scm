; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, runtime/queries/html/highlights.scm @ 692b051b09935653befdb8f7ba8afdb640adf17b, Apache-2.0.
; Unchanged.

; inherits: html_tags

(doctype) @constant

"<!" @tag.delimiter

(entity) @character.special
