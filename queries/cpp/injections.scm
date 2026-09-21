; Only patterns that name a language: a pattern naming none costs a
; match per node and injects nothing.

; Every comment carries the tags the comment grammar reads.
((comment) @injection.content
  (#set! injection.language "comment"))

; Raw string literals with language delimiter (e.g., R"cpp(...)cpp")
(raw_string_literal
  delimiter: (raw_string_delimiter) @injection.language
  (raw_string_content) @injection.content)
