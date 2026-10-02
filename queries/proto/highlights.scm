; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, runtime/queries/proto/highlights.scm @ 692b051b09935653befdb8f7ba8afdb640adf17b, Apache-2.0.
; Modified in tree-sitter-grammars.

[
  "extend"
  "extensions"
  "oneof"
  "option"
  "reserved"
  "syntax"
  "to"
] @keyword

[
  "enum"
  "service"
  "message"
] @keyword.type

"rpc" @keyword.function

"returns" @keyword.return

[
  "optional"
  "repeated"
  "required"
] @keyword.modifier

[
  "package"
  "import"
] @keyword.import

[
  (key_type)
  (type)
  (message_name)
  (enum_name)
  (service_name)
  (rpc_name)
  (message_or_enum_type)
] @type

(enum_field
  (identifier) @constant)

(string) @string

[
  "\"proto3\""
  "\"proto2\""
] @string.special

(int_lit) @number

(float_lit) @number.float

[
  (true)
  (false)
] @boolean

(comment) @comment @spell

((comment) @comment.documentation
  (#match? @comment.documentation "^/[*][*][^*][\\s\\S]*[*]/$"))

[
  "("
  ")"
  "["
  "]"
  "{"
  "}"
  "<"
  ">"
] @punctuation.bracket

[
  ";"
  ","
] @punctuation.delimiter

"=" @operator
