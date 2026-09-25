; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, runtime/queries/latex/injections.scm @ 692b051b09935653befdb8f7ba8afdb640adf17b, Apache-2.0.
; Unchanged.

([
  (line_comment)
  (block_comment)
  (comment_environment)
] @injection.content
  (#set! injection.language "comment"))

(pycode_environment
  code: (source_code) @injection.content
  (#set! injection.language "python"))

(sagesilent_environment
  code: (source_code) @injection.content
  (#set! injection.language "python"))

(sageblock_environment
  code: (source_code) @injection.content
  (#set! injection.language "python"))

(luacode_environment
  code: (source_code) @injection.content
  (#set! injection.language "lua"))

(asy_environment
  code: (source_code) @injection.content
  (#set! injection.language "c"))

(asydef_environment
  code: (source_code) @injection.content
  (#set! injection.language "c"))

(minted_environment
  (begin
    language: (curly_group_text
      (text) @injection.language))
  (source_code) @injection.content)
