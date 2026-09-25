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

; A "/**" comment holds HTML in its description and in each block tag's,
; and an @see tag's link is HTML from its "<". A description inside an
; inline tag, a snippet's body among them, lies within the description
; around it and is not injected on its own.
((document
  (description) @injection.content)
  (#set! injection.language "html"))

((document
  (_
    (description) @injection.content)) @_comment
  (#match? @_comment "^/[*][*]")
  (#set! injection.language "html"))

((url_title) @injection.content
  (#set! injection.language "html"))

; A "///" comment holds Markdown in its description and in its block
; tag's.
((markdown_description) @injection.content
  (#set! injection.language "markdown_inline"))

((document
  (_
    (description) @injection.content)) @_comment
  (#match? @_comment "^///")
  (#set! injection.language "markdown_inline"))
