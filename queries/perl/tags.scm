(package_statement
  (package) @name) @definition.module

(class_statement
  (package) @name) @definition.class

(subroutine_declaration_statement
  name: (bareword) @name) @definition.function

(method_declaration_statement
  name: (bareword) @name) @definition.method

(use_statement
  (package) @name) @reference.class

(method_call_expression
  (method) @name) @reference.call
