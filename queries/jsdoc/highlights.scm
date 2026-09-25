; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, runtime/queries/jsdoc/highlights.scm @ 692b051b09935653befdb8f7ba8afdb640adf17b, Apache-2.0.
; Modified in tree-sitter-grammars.

(tag_name) @keyword @nospell

(type) @type @nospell

[
  "{"
  "}"
  "["
  "]"
] @punctuation.bracket

[
  ":"
  "."
  "#"
  "~"
] @punctuation.delimiter

(path_expression
  "/" @punctuation.delimiter)

(identifier) @variable @nospell

(tag
  (tag_name) @_name
  (identifier) @function
  (#match? @_name "^@callback$"))

(tag
  (tag_name) @_name
  (identifier) @function
  (#match? @_name "^@function$"))

(tag
  (tag_name) @_name
  (identifier) @function
  (#match? @_name "^@func$"))

(tag
  (tag_name) @_name
  (identifier) @function
  (#match? @_name "^@method$"))

(tag
  (tag_name) @_name
  (identifier) @variable.parameter
  (#match? @_name "^@param$"))

(tag
  (tag_name) @_name
  (identifier) @variable.parameter
  (#match? @_name "^@arg$"))

(tag
  (tag_name) @_name
  (identifier) @variable.parameter
  (#match? @_name "^@argument$"))

(tag
  (tag_name) @_name
  (identifier) @property
  (#match? @_name "^@prop$"))

(tag
  (tag_name) @_name
  (identifier) @property
  (#match? @_name "^@property$"))

(tag
  (tag_name) @_name
  (identifier) @type
  (#match? @_name "^@typedef$"))
