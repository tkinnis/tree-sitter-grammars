
(class_definition
  name: (identifier) @name) @definition.class

(type_alias
  (type_identifier) @name) @definition.type

(method_signature
  (getter_signature
    name: (identifier) @name)) @definition.method

(method_signature
  (setter_signature
    name: (identifier) @name)) @definition.method

(method_signature
  (function_signature
    name: (identifier) @name)) @definition.method

(method_signature
  (factory_constructor_signature
    (identifier) @name)) @definition.method

(method_signature
  (constructor_signature
    name: (identifier) @name)) @definition.method

(method_signature
  (operator_signature
    [(binary_operator)
     "~"
     "[]"
     "[]="] @name)) @definition.method

; Constructors via declaration path (semicolon-terminated, initializer lists)
(declaration
  (constructor_signature
    name: (identifier) @name)) @definition.method

(declaration
  (constant_constructor_signature
    . (identifier) @name)) @definition.method

; Class field declarations
(declaration
  (initialized_identifier_list
    (initialized_identifier
      . (identifier) @name))) @definition.property

(declaration
  (static_final_declaration_list
    (static_final_declaration
      . (identifier) @name))) @definition.property

(mixin_declaration
  (mixin)
  (identifier) @name) @definition.mixin

(extension_declaration
  name: (identifier) @name) @definition.extension


(new_expression
  (type_identifier) @name) @reference.class

(enum_declaration
  name: (identifier) @name) @definition.enum

(function_signature
  name: (identifier) @name) @definition.function 

(initialized_variable_definition
  name: (identifier)
  value: (identifier) @name 
  value: (selector
	"!"?
	(argument_part 
	  (arguments
	    (argument)*))?)?) @reference.class

(assignment_expression
  left: (assignable_expression 
		  (identifier)
		  (unconditional_assignable_selector
			"."
			(identifier) @name))) @reference.call

(assignment_expression
  left: (assignable_expression 
		  (identifier)
		  (conditional_assignable_selector
			"?."
			(identifier) @name))) @reference.call

((identifier) @name
 (selector
    "!"?
    (conditional_assignable_selector
      "?." (identifier) @name)?
    (unconditional_assignable_selector
      "."? (identifier) @name)?
    (argument_part
      (arguments
        (argument)*))?)*
	(cascade_section
	  (cascade_selector
		(identifier)) @name 
	  (argument_part 
		(arguments
		  (argument)*))?)?) @reference.call

