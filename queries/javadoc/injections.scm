; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, runtime/queries/javadoc/injections.scm @ 692b051b09935653befdb8f7ba8afdb640adf17b, Apache-2.0.
; Modified in tree-sitter-grammars.

; injected code snippets
((snippet_tag
  (attributes
    (attribute
      name: (identifier) @_attribute_key
      value: (attribute_value
        [
          (identifier) @injection.language
          (string_literal
            (quoted_value) @injection.language)
        ])))
  body: (description) @injection.content)
  (#match? @_attribute_key "^lang$"))

; html content
((description) @injection.content
  (#set! injection.language "html"))

; markdown content
((markdown_description) @injection.content
  (#set! injection.language "markdown_inline"))
