; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, runtime/queries/markdown_inline/highlights.scm @ 692b051b09935653befdb8f7ba8afdb640adf17b, Apache-2.0.
; Modified in tree-sitter-grammars.

; From MDeiml/tree-sitter-markdown
(code_span) @markup.raw @nospell

(emphasis) @markup.italic

(strong_emphasis) @markup.strong

(strikethrough) @markup.strikethrough

(shortcut_link
  (link_text) @nospell)

[
  (backslash_escape)
  (hard_line_break)
] @string.escape

; Conceal codeblock and text style markers
([
  (code_span_delimiter)
  (emphasis_delimiter)
] @conceal
)

; Conceal inline links
(inline_link
  [
    "["
    "]"
    "("
    (link_destination)
    ")"
  ] @markup.link
)

[
  (link_label)
  (link_text)
  (link_title)
  (image_description)
] @markup.link.label

((inline_link
  (link_destination) @_url) @_label
)

((image
  (link_destination) @_url) @_label
)

; Conceal image links
(image
  [
    "!"
    "["
    "]"
    "("
    (link_destination)
    ")"
  ] @markup.link
)

; Conceal full reference links
(full_reference_link
  [
    "["
    "]"
    (link_label)
  ] @markup.link
)

; Conceal collapsed reference links
(collapsed_reference_link
  [
    "["
    "]"
  ] @markup.link
)

; Conceal shortcut links
(shortcut_link
  [
    "["
    "]"
  ] @markup.link
)

[
  (link_destination)
  (uri_autolink)
  (email_autolink)
] @markup.link.url @nospell

((uri_autolink) @_url
)

(entity_reference) @nospell

; Replace common HTML entities.
((entity_reference) @character.special
  (#eq? @character.special "&nbsp;")
)

((entity_reference) @character.special
  (#eq? @character.special "&lt;")
)

((entity_reference) @character.special
  (#eq? @character.special "&gt;")
)

((entity_reference) @character.special
  (#eq? @character.special "&amp;")
)

((entity_reference) @character.special
  (#eq? @character.special "&quot;")
)

((entity_reference) @character.special
  (#match? @character.special "^&ensp;$")
)

((entity_reference) @character.special
  (#match? @character.special "^&emsp;$")
)
