((tag
  (name) @comment.todo @nospell
  ("("
    (user) @constant
    ")")?
  ":")
  (#any-of? @comment.todo "TODO" "WIP"))

("text" @comment.todo @nospell
  (#any-of? @comment.todo "TODO" "WIP"))

((tag
  (name) @comment.note @nospell
  ("("
    (user) @constant
    ")")?
  ":")
  (#any-of? @comment.note "NOTE" "XXX" "INFO" "DOCS" "PERF" "TEST"))

("text" @comment.note @nospell
  (#any-of? @comment.note "NOTE" "XXX" "INFO" "DOCS" "PERF" "TEST"))

((tag
  (name) @comment.warning @nospell
  ("("
    (user) @constant
    ")")?
  ":")
  (#any-of? @comment.warning "HACK" "WARNING" "WARN" "FIX"))

("text" @comment.warning @nospell
  (#any-of? @comment.warning "HACK" "WARNING" "WARN" "FIX"))

((tag
  (name) @comment.error @nospell
  ("("
    (user) @constant
    ")")?
  ":")
  (#any-of? @comment.error "FIXME" "BUG" "ERROR"))

("text" @comment.error @nospell
  (#any-of? @comment.error "FIXME" "BUG" "ERROR"))

; An issue number: `#123`.
("text" @number
  (#match? @number "^#[0-9]+$"))

(uri) @string.special.url @nospell
