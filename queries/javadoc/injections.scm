; @value tags without double-quotes
((bare_format_string) @injection.content
)

; @value tags with double quotes
((literal_format_string) @injection.content
)

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
)

; markdown content
((markdown_description) @injection.content
)
