; The tests a file registers by call, and the groups each is registered
; under, as package:test and flutter_test register them: a test is a call
; to `test` or `testWidgets`, and a group a call to `group` whose last
; function argument holds what the group registers. An editor reads from
; these which groups enclose a test, outermost first, and withholds an
; answer wherever the source cannot say what a run will call them.
;
; @test         the name of a function called to register a test: a direct
;               call of `test` or `testWidgets`, as a statement, after
;               `await` or as the body of an arrow function. A member of
;               either, `test.skip`, and a function that merely has the
;               name are not calls of it. Its @test.name.open and
;               @test.name.close are the quote that opens the test's name
;               and the one that closes it, where the name is plain text.
; @group        a call registering a group named by plain text. Its
;               @group.name.open and @group.name.close are the quote that
;               opens the name and the one that closes it, the name being
;               the text between them, and @group.body is the body of the
;               function it registers its tests in.
; @unnamed      a call registering a group whose name is not plain text: a
;               variable, an expression, a string with an interpolation,
;               an escape or a raw or triple-quoted spelling. Its
;               @group.body is the body of its function.
; @opaque       the body of a function. A test inside one that is no
;               group's @group.body is registered under whatever groups
;               enclose the call of that function, which the source does
;               not say.
; @rebinding    a binding of the name of `test`, `testWidgets` or `group`,
;               which leaves a call of that name meaning whatever the
;               binding made it.
;
; Plain text is a single- or double-quoted string of one or more
; characters with no `$` and no backslash, matched by the same expression
; in every pattern below that tells a named group from an unnamed one.

; Groups named by plain text.

(_
  (identifier) @_group
  .
  (selector
    (argument_part
      (arguments
        .
        (argument
          (string_literal
            .
            _ @group.name.open
            .
            _ @group.name.close
            .) @_name)
        (argument
          (function_expression
            body: (function_expression_body) @group.body)))))
  (#eq? @_group "group")
  (#match? @_name "^(?:'[^'\\\\\n$]+'|\"[^\"\\\\\n$]+\")$")) @group

; Groups named by anything else.

(_
  (identifier) @_group
  .
  (selector
    (argument_part
      (arguments
        .
        (argument) @_name
        (argument
          (function_expression
            body: (function_expression_body) @group.body)))))
  (#eq? @_group "group")
  (#not-match? @_name "^(?:'[^'\\\\\n$]+'|\"[^\"\\\\\n$]+\")$")) @unnamed

; Tests named by plain text.

((identifier) @test
  .
  (selector
    (argument_part
      (arguments
        .
        (argument
          (string_literal
            .
            _ @test.name.open
            .
            _ @test.name.close
            .) @_name))))
  (#any-of? @test "test" "testWidgets")
  (#match? @_name "^(?:'[^'\\\\\n$]+'|\"[^\"\\\\\n$]+\")$"))

; Tests named by anything else. A call of a function that is no test's
; registration is told from one by the function it is handed.

((identifier) @test
  .
  (selector
    (argument_part
      (arguments
        .
        (argument) @_name
        (argument (function_expression)))))
  (#any-of? @test "test" "testWidgets")
  (#not-match? @_name "^(?:'[^'\\\\\n$]+'|\"[^\"\\\\\n$]+\")$"))

; The bodies of functions. `main` is where a file's tests are written, and
; holds them with no group around them; any other function or method is
; called from somewhere the source does not say.

(function_expression
  body: (function_expression_body) @opaque)

((function_signature
  name: (identifier) @_name)
  .
  (function_body) @opaque
  (#not-eq? @_name "main"))

((method_signature)
  .
  (function_body) @opaque)

; Bindings of the name of a registering function.

(function_signature
  name: (identifier) @rebinding
  (#any-of? @rebinding "test" "testWidgets" "group"))

(initialized_variable_definition
  name: (identifier) @rebinding
  (#any-of? @rebinding "test" "testWidgets" "group"))

(formal_parameter
  (identifier) @rebinding
  (#any-of? @rebinding "test" "testWidgets" "group"))
