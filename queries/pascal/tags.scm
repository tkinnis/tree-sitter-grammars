(program
  (moduleName
    (identifier) @name)) @definition.module

(defProc
  header: (declProc
    name: (identifier) @name)) @definition.function

(declConst
  name: (identifier) @name) @definition.constant

(declType
  name: (identifier) @name) @definition.type

(declVar
  name: (identifier) @name) @definition.variable
