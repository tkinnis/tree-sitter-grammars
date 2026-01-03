(fenced_code_block
  (info_string
    (language) @injection.language)
  (code_fence_content) @injection.content
)

((html_block) @injection.content
 (#set! injection.language "html"))

((minus_metadata) @injection.content
 (#set! injection.language "yaml"))

((plus_metadata) @injection.content
 (#set! injection.language "yaml"))

((inline) @injection.content
 (#set! injection.language "markdown_inline"))

((pipe_table_cell) @injection.content
 (#set! injection.language "markdown_inline"))
