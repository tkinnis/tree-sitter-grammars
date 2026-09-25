; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, runtime/queries/dtd/highlights.scm @ 692b051b09935653befdb8f7ba8afdb640adf17b, Apache-2.0.
; Modified in tree-sitter-grammars.

; Text declaration
(TextDecl
  "xml" @keyword.directive)

(TextDecl
  [
    "version"
    "encoding"
  ] @tag.attribute)

(TextDecl
  (EncName) @string.special)

(TextDecl
  (VersionNum) @number)

; Processing instructions
(PI) @keyword.directive

; Element declaration
(elementdecl
  "ELEMENT" @keyword.directive.define
  (Name) @tag)

(contentspec
  (_
    (Name) @tag.attribute))

"#PCDATA" @type.builtin

[
  "EMPTY"
  "ANY"
] @keyword.modifier

[
  "*"
  "?"
  "+"
] @character.special

; Entity declaration
(GEDecl
  "ENTITY" @keyword.directive.define
  (Name) @constant)

(GEDecl
  (EntityValue) @string)

(NDataDecl
  "NDATA" @keyword
  (Name) @label)

; Parsed entity declaration
(PEDecl
  "ENTITY" @keyword.directive.define
  "%" @operator
  (Name) @function.macro)

(PEDecl
  (EntityValue) @string)

; Notation declaration
(NotationDecl
  "NOTATION" @keyword.directive
  (Name) @label)

; Attlist declaration
(AttlistDecl
  "ATTLIST" @keyword.directive.define
  (Name) @tag)

(AttDef
  (Name) @tag.attribute)

(AttDef
  (Enumeration
    (Nmtoken) @string))

[
  (StringType)
  (TokenizedType)
] @type.builtin

(NotationType
  "NOTATION" @type.builtin)

[
  "#REQUIRED"
  "#IMPLIED"
  "#FIXED"
] @attribute

; Entities
(EntityRef) @constant

((EntityRef) @constant.builtin
  (#match? @constant.builtin "^&amp;$"))

((EntityRef) @constant.builtin
  (#match? @constant.builtin "^&lt;$"))

((EntityRef) @constant.builtin
  (#match? @constant.builtin "^&gt;$"))

((EntityRef) @constant.builtin
  (#match? @constant.builtin "^&quot;$"))

((EntityRef) @constant.builtin
  (#match? @constant.builtin "^&apos;$"))

(CharRef) @character

(PEReference) @function.macro

; External references
[
  "PUBLIC"
  "SYSTEM"
] @keyword

(PubidLiteral) @string.special

(SystemLiteral
  (URI) @string.special.url)

; Delimiters & punctuation
[
  "<?"
  "?>"
  "<!"
  ">"
  "<!["
  "]]>"
] @tag.delimiter

[
  "("
  ")"
  "["
] @punctuation.bracket

[
  "\""
  "'"
] @punctuation.delimiter

[
  ","
  "|"
  "="
] @operator

; Misc
[
  "INCLUDE"
  "IGNORE"
] @keyword.import

(Comment) @comment @spell
