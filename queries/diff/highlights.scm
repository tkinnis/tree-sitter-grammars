; Derived from nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter, runtime/queries/diff/highlights.scm @ 692b051b09935653befdb8f7ba8afdb640adf17b, Apache-2.0.
; Modified in tree-sitter-grammars.

(comment) @comment @spell

([
  ".."
  "+"
  "++"
  "+++"
  "++++"
  "-"
  "--"
  "---"
  "----"
] @punctuation.special
)

[
  (addition)
  (new_file)
] @diff.plus

[
  (deletion)
  (old_file)
] @diff.minus

(commit) @constant

(location) @attribute

(command
  "diff" @function
  (argument) @variable.parameter)

(filename) @string.special.path

(mode) @number

[
  (binary_change)
  (similarity)
  (file_change)
] @label

(index
  "index" @keyword)

(similarity
  (score) @number
  "%" @number)
