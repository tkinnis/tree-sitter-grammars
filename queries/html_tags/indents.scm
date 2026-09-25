; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, runtime/queries/html_tags/indents.scm @ 692b051b09935653befdb8f7ba8afdb640adf17b, Apache-2.0.
; Modified in tree-sitter-grammars.

((element
  (start_tag
    (tag_name) @_not_void_element))
  (#not-any-of? @_not_void_element
    "area" "base" "basefont" "bgsound" "br" "col" "command" "embed" "frame" "hr" "image" "img"
    "input" "isindex" "keygen" "link" "menuitem" "meta" "nextid" "param" "source" "track" "wbr")) @indent.begin

(element
  (self_closing_tag)) @indent.begin

((start_tag
  (tag_name) @_void_element)
  (#any-of? @_void_element
    "area" "base" "basefont" "bgsound" "br" "col" "command" "embed" "frame" "hr" "image" "img"
    "input" "isindex" "keygen" "link" "menuitem" "meta" "nextid" "param" "source" "track" "wbr")) @indent.begin

; These are the nodes that will be captured when we do `normal o`
; But last element has already been ended, so capturing this
; to mark end of last element
(element
  (end_tag
    ">" @indent.end))

(element
  (self_closing_tag
    "/>" @indent.end))

; End tags should dedent to match their opening tag
(element
  (end_tag) @indent.dedent)

(comment) @indent.ignore
