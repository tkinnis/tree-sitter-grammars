(list_lit
  .
  (sym_lit) @keyword
  (#match? @keyword "^(defun|defmacro|defgeneric|defmethod)$")
  (sym_lit) @name) @definition.function

(list_lit
  .
  (sym_lit) @keyword
  (#match? @keyword "^(defclass|defstruct)$")
  (sym_lit) @name) @definition.class

(list_lit
  .
  (sym_lit) @keyword
  (#match? @keyword "^(defvar|defparameter|defconstant)$")
  (sym_lit) @name) @definition.variable

(list_lit
  .
  (sym_lit) @keyword
  (#match? @keyword "^(defpackage|in-package)$")
  (sym_lit) @name) @definition.module
