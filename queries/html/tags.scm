(element
  (start_tag
    (tag_name) @name)) @definition.element

(script_element
  (start_tag
    (tag_name) @name)) @definition.element

(style_element
  (start_tag
    (tag_name) @name)) @definition.element

(element
  (start_tag
    (attribute
      (attribute_name) @attr_name
      (#eq? @attr_name "id")
      (quoted_attribute_value
        (attribute_value) @name)))) @definition.id
