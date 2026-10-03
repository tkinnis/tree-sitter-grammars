; The tests a file registers by call, and the groups each is registered
; under, as jest, bun, vitest and mocha register them: a test is a call to
; `test` or `it`, and a group a call to `describe`, `context`, `suite`,
; `fdescribe` or `xdescribe` whose last argument is the function holding
; what the group registers. An editor reads from these which groups
; enclose a test, outermost first, and withholds an answer wherever the
; source cannot say what a run will call them.
;
; @test         a call registering a test.
; @group        a call registering a group named by plain text, with
;               @group.name that text and @group.body the body of the
;               function it registers its tests in.
; @unnamed      a call registering a group whose name is not plain text: a
;               variable, an expression, a template with a substitution,
;               a string with an escape or no text at all. Its
;               @group.body is the body of its function.
; @table        a call registering one group per row of a table
;               (`describe.each`, `describe.for`), each named by a row.
;               Its @group.body is the body of its function.
; @opaque       the body of a function. A test inside one that is no
;               group's @group.body is registered under whatever groups
;               enclose the call of that function, which the source does
;               not say.
; @rebinding    a binding of a group function's name, which leaves a call
;               of that name meaning whatever the binding made it.
;
; Plain text is a string or a template literal holding one or more
; characters, no escape and no `${`, matched by the same expression in
; every pattern below that tells a named group from an unnamed one.

; Groups named by plain text.

(call_expression
  function: (identifier) @_group
  arguments: (arguments
    .
    [
      (string (string_fragment) @group.name)
      (template_string (string_fragment) @group.name)
    ] @_name
    .
    [
      (arrow_function body: (_) @group.body)
      (function_expression body: (statement_block) @group.body)
    ])
  (#any-of? @_group "describe" "context" "suite" "fdescribe" "xdescribe")
  (#match? @_name "^(?:'[^'\\\\\n]+'|\"[^\"\\\\\n]+\"|`[^`\\\\$]+`)$")) @group

(call_expression
  function: (member_expression
    object: (identifier) @_group
    property: (property_identifier) @_modifier)
  arguments: (arguments
    .
    [
      (string (string_fragment) @group.name)
      (template_string (string_fragment) @group.name)
    ] @_name
    .
    [
      (arrow_function body: (_) @group.body)
      (function_expression body: (statement_block) @group.body)
    ])
  (#any-of? @_group "describe" "context" "suite" "fdescribe" "xdescribe")
  (#any-of? @_modifier "only" "skip" "todo" "concurrent" "sequential" "shuffle")
  (#match? @_name "^(?:'[^'\\\\\n]+'|\"[^\"\\\\\n]+\"|`[^`\\\\$]+`)$")) @group

(call_expression
  function: (member_expression
    object: (member_expression
      object: (identifier) @_group
      property: (property_identifier) @_modifier)
    property: (property_identifier) @_also)
  arguments: (arguments
    .
    [
      (string (string_fragment) @group.name)
      (template_string (string_fragment) @group.name)
    ] @_name
    .
    [
      (arrow_function body: (_) @group.body)
      (function_expression body: (statement_block) @group.body)
    ])
  (#any-of? @_group "describe" "context" "suite" "fdescribe" "xdescribe")
  (#any-of? @_modifier "only" "skip" "todo" "concurrent" "sequential" "shuffle")
  (#any-of? @_also "only" "skip" "todo" "concurrent" "sequential" "shuffle")
  (#match? @_name "^(?:'[^'\\\\\n]+'|\"[^\"\\\\\n]+\"|`[^`\\\\$]+`)$")) @group

; A group registered only where a condition holds, `describe.if(ok)(…)`,
; is named as the call it returns is.
(call_expression
  function: (call_expression
    function: (member_expression
      object: (identifier) @_group
      property: (property_identifier) @_condition))
  arguments: (arguments
    .
    [
      (string (string_fragment) @group.name)
      (template_string (string_fragment) @group.name)
    ] @_name
    .
    [
      (arrow_function body: (_) @group.body)
      (function_expression body: (statement_block) @group.body)
    ])
  (#any-of? @_group "describe" "context" "suite" "fdescribe" "xdescribe")
  (#any-of? @_condition "if" "skipIf" "todoIf" "runIf")
  (#match? @_name "^(?:'[^'\\\\\n]+'|\"[^\"\\\\\n]+\"|`[^`\\\\$]+`)$")) @group

; Groups named by anything else.

(call_expression
  function: (identifier) @_group
  arguments: (arguments
    .
    (_) @_name
    .
    [
      (arrow_function body: (_) @group.body)
      (function_expression body: (statement_block) @group.body)
    ])
  (#any-of? @_group "describe" "context" "suite" "fdescribe" "xdescribe")
  (#not-match? @_name "^(?:'[^'\\\\\n]+'|\"[^\"\\\\\n]+\"|`[^`\\\\$]+`)$")) @unnamed

(call_expression
  function: (member_expression
    object: (identifier) @_group
    property: (property_identifier) @_modifier)
  arguments: (arguments
    .
    (_) @_name
    .
    [
      (arrow_function body: (_) @group.body)
      (function_expression body: (statement_block) @group.body)
    ])
  (#any-of? @_group "describe" "context" "suite" "fdescribe" "xdescribe")
  (#any-of? @_modifier "only" "skip" "todo" "concurrent" "sequential" "shuffle")
  (#not-match? @_name "^(?:'[^'\\\\\n]+'|\"[^\"\\\\\n]+\"|`[^`\\\\$]+`)$")) @unnamed

(call_expression
  function: (member_expression
    object: (member_expression
      object: (identifier) @_group
      property: (property_identifier) @_modifier)
    property: (property_identifier) @_also)
  arguments: (arguments
    .
    (_) @_name
    .
    [
      (arrow_function body: (_) @group.body)
      (function_expression body: (statement_block) @group.body)
    ])
  (#any-of? @_group "describe" "context" "suite" "fdescribe" "xdescribe")
  (#any-of? @_modifier "only" "skip" "todo" "concurrent" "sequential" "shuffle")
  (#any-of? @_also "only" "skip" "todo" "concurrent" "sequential" "shuffle")
  (#not-match? @_name "^(?:'[^'\\\\\n]+'|\"[^\"\\\\\n]+\"|`[^`\\\\$]+`)$")) @unnamed

(call_expression
  function: (call_expression
    function: (member_expression
      object: (identifier) @_group
      property: (property_identifier) @_condition))
  arguments: (arguments
    .
    (_) @_name
    .
    [
      (arrow_function body: (_) @group.body)
      (function_expression body: (statement_block) @group.body)
    ])
  (#any-of? @_group "describe" "context" "suite" "fdescribe" "xdescribe")
  (#any-of? @_condition "if" "skipIf" "todoIf" "runIf")
  (#not-match? @_name "^(?:'[^'\\\\\n]+'|\"[^\"\\\\\n]+\"|`[^`\\\\$]+`)$")) @unnamed

; Groups registered once per row of a table, whatever names them:
; `describe.each([…])(…)`, `describe.each`…``(…)` and `describe.for(…)(…)`,
; under a modifier or not.

(call_expression
  function: (call_expression
    function: (member_expression
      object: (identifier) @_group
      property: (property_identifier) @_table))
  arguments: (arguments
    (_)
    .
    [
      (arrow_function body: (_) @group.body)
      (function_expression body: (statement_block) @group.body)
    ])
  (#any-of? @_group "describe" "context" "suite" "fdescribe" "xdescribe")
  (#any-of? @_table "each" "for")) @table

(call_expression
  function: (call_expression
    function: (member_expression
      object: (member_expression
        object: (identifier) @_group
        property: (property_identifier) @_modifier)
      property: (property_identifier) @_table))
  arguments: (arguments
    (_)
    .
    [
      (arrow_function body: (_) @group.body)
      (function_expression body: (statement_block) @group.body)
    ])
  (#any-of? @_group "describe" "context" "suite" "fdescribe" "xdescribe")
  (#any-of? @_modifier "only" "skip" "todo" "concurrent" "sequential" "shuffle")
  (#any-of? @_table "each" "for")) @table

; Tests. A test registered once per row of a table, `it.each([…])(…)`, is
; one call to `it.each` and a second to what it returns, and both start
; where the test does.

(call_expression
  function: (identifier) @_test
  (#any-of? @_test "test" "it" "fit" "xit" "xtest")) @test

(call_expression
  function: (member_expression
    object: (identifier) @_test
    property: (property_identifier) @_modifier)
  (#any-of? @_test "test" "it" "fit" "xit" "xtest")
  (#any-of? @_modifier "only" "skip" "todo" "concurrent" "sequential" "failing" "fails" "each" "for" "if" "skipIf" "todoIf" "runIf")) @test

(call_expression
  function: (member_expression
    object: (member_expression
      object: (identifier) @_test
      property: (property_identifier) @_modifier)
    property: (property_identifier) @_also)
  (#any-of? @_test "test" "it" "fit" "xit" "xtest")
  (#any-of? @_modifier "only" "skip" "todo" "concurrent" "sequential" "failing" "fails" "each" "for" "if" "skipIf" "todoIf" "runIf")
  (#any-of? @_also "only" "skip" "todo" "concurrent" "sequential" "failing" "fails" "each" "for" "if" "skipIf" "todoIf" "runIf")) @test

(call_expression
  function: (call_expression
    function: (member_expression
      object: (identifier) @_test
      property: (property_identifier) @_modifier))
  (#any-of? @_test "test" "it" "fit" "xit" "xtest")
  (#any-of? @_modifier "each" "for" "if" "skipIf" "todoIf" "runIf")) @test

(call_expression
  function: (call_expression
    function: (member_expression
      object: (member_expression
        object: (identifier) @_test
        property: (property_identifier) @_modifier)
      property: (property_identifier) @_also))
  (#any-of? @_test "test" "it" "fit" "xit" "xtest")
  (#any-of? @_modifier "only" "skip" "todo" "concurrent" "sequential" "failing" "fails")
  (#any-of? @_also "each" "for" "if" "skipIf" "todoIf" "runIf")) @test

; The bodies of functions.

(arrow_function body: (_) @opaque)

(function_expression body: (statement_block) @opaque)

(function_declaration body: (statement_block) @opaque)

(generator_function body: (statement_block) @opaque)

(generator_function_declaration body: (statement_block) @opaque)

(method_definition body: (statement_block) @opaque)

; Bindings of a group function's name. An import names the function the
; runner's own module exports, and leaves it as it is.

(variable_declarator
  name: (identifier) @rebinding
  (#any-of? @rebinding "describe" "context" "suite" "fdescribe" "xdescribe"))

(variable_declarator
  name: (object_pattern
    (shorthand_property_identifier_pattern) @rebinding)
  (#any-of? @rebinding "describe" "context" "suite" "fdescribe" "xdescribe"))

(variable_declarator
  name: (object_pattern
    (pair_pattern value: (identifier) @rebinding))
  (#any-of? @rebinding "describe" "context" "suite" "fdescribe" "xdescribe"))

(variable_declarator
  name: (array_pattern (identifier) @rebinding)
  (#any-of? @rebinding "describe" "context" "suite" "fdescribe" "xdescribe"))

(assignment_expression
  left: (identifier) @rebinding
  (#any-of? @rebinding "describe" "context" "suite" "fdescribe" "xdescribe"))

(function_declaration
  name: (identifier) @rebinding
  (#any-of? @rebinding "describe" "context" "suite" "fdescribe" "xdescribe"))

(class_declaration
  name: (_) @rebinding
  (#any-of? @rebinding "describe" "context" "suite" "fdescribe" "xdescribe"))

(import_clause
  (identifier) @rebinding
  (#any-of? @rebinding "describe" "context" "suite" "fdescribe" "xdescribe"))

(namespace_import
  (identifier) @rebinding
  (#any-of? @rebinding "describe" "context" "suite" "fdescribe" "xdescribe"))

(import_specifier
  alias: (identifier) @rebinding
  (#any-of? @rebinding "describe" "context" "suite" "fdescribe" "xdescribe"))

(import_statement
  (import_clause
    (named_imports
      (import_specifier
        name: (identifier) @rebinding
        !alias)))
  source: (string (string_fragment) @_module)
  (#any-of? @rebinding "describe" "context" "suite" "fdescribe" "xdescribe")
  (#not-any-of? @_module "@jest/globals" "bun:test" "vitest" "node:test" "mocha"))
