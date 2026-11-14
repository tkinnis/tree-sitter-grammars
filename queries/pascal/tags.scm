(program
  (moduleName
    (identifier) @name)) @definition.module

(defProc
  header: (declProc
    name: (identifier) @name)) @definition.function

(declConst
  name: (identifier) @name) @definition.constant

(declType
  name: (identifier) @name
  type: [
    (declClass)
    (declHelper)
    (declIntf)
  ]) @definition.type

(declType
  name: (identifier) @name
  type: (type
    [
      (declArray)
      (declFile)
      (declMetaClass)
      (declProcRef)
      (declSet)
      (declString)
      (pp)
      (typeref)
    ])) @definition.type

(declType
  name: (identifier) @name
  type: (type
    (declEnum))) @definition.enum

(declEnumValue
  name: (identifier) @name) @definition.enum_member

(declVar
  name: (identifier) @name) @definition.variable
