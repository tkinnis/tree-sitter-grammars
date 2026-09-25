; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, runtime/queries/yaml/injections.scm @ 692b051b09935653befdb8f7ba8afdb640adf17b, Apache-2.0.
; Modified in tree-sitter-grammars.

((comment) @injection.content
  (#set! injection.language "comment"))

; Github actions ("run") / Gitlab CI ("scripts")
; Taskfile scripts ("cmds", "cmd", "sh")
(block_mapping_pair
  key: (flow_node) @_run
  (#match? @_run "^run$")
  value: (flow_node
    (plain_scalar
      (string_scalar) @injection.content)
))

(block_mapping_pair
  key: (flow_node) @_run
  (#match? @_run "^script$")
  value: (flow_node
    (plain_scalar
      (string_scalar) @injection.content)
))

(block_mapping_pair
  key: (flow_node) @_run
  (#match? @_run "^before_script$")
  value: (flow_node
    (plain_scalar
      (string_scalar) @injection.content)
))

(block_mapping_pair
  key: (flow_node) @_run
  (#match? @_run "^after_script$")
  value: (flow_node
    (plain_scalar
      (string_scalar) @injection.content)
))

(block_mapping_pair
  key: (flow_node) @_run
  (#match? @_run "^cmds$")
  value: (flow_node
    (plain_scalar
      (string_scalar) @injection.content)
))

(block_mapping_pair
  key: (flow_node) @_run
  (#match? @_run "^cmd$")
  value: (flow_node
    (plain_scalar
      (string_scalar) @injection.content)
))

(block_mapping_pair
  key: (flow_node) @_run
  (#match? @_run "^sh$")
  value: (flow_node
    (plain_scalar
      (string_scalar) @injection.content)
))

(block_mapping_pair
  key: (flow_node) @_run
  (#match? @_run "^run$")
  value: (block_node
    (block_scalar) @injection.content
))

(block_mapping_pair
  key: (flow_node) @_run
  (#match? @_run "^script$")
  value: (block_node
    (block_scalar) @injection.content
))

(block_mapping_pair
  key: (flow_node) @_run
  (#match? @_run "^before_script$")
  value: (block_node
    (block_scalar) @injection.content
))

(block_mapping_pair
  key: (flow_node) @_run
  (#match? @_run "^after_script$")
  value: (block_node
    (block_scalar) @injection.content
))

(block_mapping_pair
  key: (flow_node) @_run
  (#match? @_run "^cmds$")
  value: (block_node
    (block_scalar) @injection.content
))

(block_mapping_pair
  key: (flow_node) @_run
  (#match? @_run "^cmd$")
  value: (block_node
    (block_scalar) @injection.content
))

(block_mapping_pair
  key: (flow_node) @_run
  (#match? @_run "^sh$")
  value: (block_node
    (block_scalar) @injection.content
))

(block_mapping_pair
  key: (flow_node) @_run
  (#match? @_run "^run$")
  value: (block_node
    (block_sequence
      (block_sequence_item
        (flow_node
          (plain_scalar
            (string_scalar) @injection.content))
))))

(block_mapping_pair
  key: (flow_node) @_run
  (#match? @_run "^script$")
  value: (block_node
    (block_sequence
      (block_sequence_item
        (flow_node
          (plain_scalar
            (string_scalar) @injection.content))
))))

(block_mapping_pair
  key: (flow_node) @_run
  (#match? @_run "^before_script$")
  value: (block_node
    (block_sequence
      (block_sequence_item
        (flow_node
          (plain_scalar
            (string_scalar) @injection.content))
))))

(block_mapping_pair
  key: (flow_node) @_run
  (#match? @_run "^after_script$")
  value: (block_node
    (block_sequence
      (block_sequence_item
        (flow_node
          (plain_scalar
            (string_scalar) @injection.content))
))))

(block_mapping_pair
  key: (flow_node) @_run
  (#match? @_run "^cmds$")
  value: (block_node
    (block_sequence
      (block_sequence_item
        (flow_node
          (plain_scalar
            (string_scalar) @injection.content))
))))

(block_mapping_pair
  key: (flow_node) @_run
  (#match? @_run "^sh$")
  value: (block_node
    (block_sequence
      (block_sequence_item
        (flow_node
          (plain_scalar
            (string_scalar) @injection.content))
))))

(block_mapping_pair
  key: (flow_node) @_run
  (#match? @_run "^script$")
  value: (block_node
    (block_sequence
      (block_sequence_item
        (block_node
          (block_scalar) @injection.content
)))))

(block_mapping_pair
  key: (flow_node) @_run
  (#match? @_run "^before_script$")
  value: (block_node
    (block_sequence
      (block_sequence_item
        (block_node
          (block_scalar) @injection.content
)))))

(block_mapping_pair
  key: (flow_node) @_run
  (#match? @_run "^after_script$")
  value: (block_node
    (block_sequence
      (block_sequence_item
        (block_node
          (block_scalar) @injection.content
)))))

(block_mapping_pair
  key: (flow_node) @_run
  (#match? @_run "^cmds$")
  value: (block_node
    (block_sequence
      (block_sequence_item
        (block_node
          (block_scalar) @injection.content
)))))

(block_mapping_pair
  key: (flow_node) @_run
  (#match? @_run "^sh$")
  value: (block_node
    (block_sequence
      (block_sequence_item
        (block_node
          (block_scalar) @injection.content
)))))

; Prometheus Alertmanager ("expr")
(block_mapping_pair
  key: (flow_node) @_expr
  (#match? @_expr "^expr$")
  value: (flow_node
    (plain_scalar
      (string_scalar) @injection.content)
))

(block_mapping_pair
  key: (flow_node) @_expr
  (#match? @_expr "^expr$")
  value: (block_node
    (block_scalar) @injection.content
))

(block_mapping_pair
  key: (flow_node) @_expr
  (#match? @_expr "^expr$")
  value: (block_node
    (block_sequence
      (block_sequence_item
        (flow_node
          (plain_scalar
            (string_scalar) @injection.content))
))))

(block_mapping_pair
  key: (flow_node) @_expr
  (#match? @_expr "^expr$")
  value: (block_node
    (block_sequence
      (block_sequence_item
        (block_node
          (block_scalar) @injection.content
)))))
