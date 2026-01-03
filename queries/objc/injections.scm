((preproc_arg) @injection.content
)

((comment) @injection.content
)

((comment) @injection.content
  (#match? @injection.content "/\\*!([a-zA-Z]+:)?re2c")
)

((comment) @injection.content
  (#match? @injection.content "/[*\/][!*\/]<?[^a-zA-Z]")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^printf$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^printf_s$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^vprintf$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^vprintf_s$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^scanf$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^scanf_s$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^vscanf$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^vscanf_s$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^wprintf$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^wprintf_s$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^vwprintf$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^vwprintf_s$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^wscanf$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^wscanf_s$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^vwscanf$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^vwscanf_s$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^cscanf$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^_cscanf$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^printw$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^scanw$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    (_)
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^fprintf$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    (_)
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^fprintf_s$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    (_)
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^sprintf$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    (_)
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^dprintf$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    (_)
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^fscanf$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    (_)
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^fscanf_s$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    (_)
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^sscanf$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    (_)
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^sscanf_s$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    (_)
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^vsscanf$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    (_)
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^vsscanf_s$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    (_)
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^vfprintf$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    (_)
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^vfprintf_s$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    (_)
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^vsprintf$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    (_)
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^vdprintf$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    (_)
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^fwprintf$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    (_)
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^fwprintf_s$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    (_)
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^vfwprintf$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    (_)
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^vfwprintf_s$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    (_)
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^fwscanf$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    (_)
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^fwscanf_s$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    (_)
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^swscanf$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    (_)
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^swscanf_s$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    (_)
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^vswscanf$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    (_)
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^vswscanf_s$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    (_)
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^vfscanf$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    (_)
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^vfscanf_s$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    (_)
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^vfwscanf$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    (_)
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^vfwscanf_s$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    (_)
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^wprintw$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    (_)
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^vw_printw$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    (_)
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^vwprintw$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    (_)
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^wscanw$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    (_)
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^vw_scanw$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    (_)
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^vwscanw$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    (_)
    .
    (_)
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^sprintf_s$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    (_)
    .
    (_)
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^snprintf$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    (_)
    .
    (_)
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^snprintf_s$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    (_)
    .
    (_)
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^vsprintf_s$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    (_)
    .
    (_)
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^vsnprintf$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    (_)
    .
    (_)
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^vsnprintf_s$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    (_)
    .
    (_)
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^swprintf$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    (_)
    .
    (_)
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^swprintf_s$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    (_)
    .
    (_)
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^snwprintf_s$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    (_)
    .
    (_)
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^vswprintf$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    (_)
    .
    (_)
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^vswprintf_s$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    (_)
    .
    (_)
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^vsnwprintf_s$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    (_)
    .
    (_)
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^mvprintw$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    (_)
    .
    (_)
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  ; format-ignore
  (#match? @_function "^mvscanw$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    (_)
    .
    (_)
    .
    (_)
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  (#match? @_function "^mvwprintw$")
)

((call_expression
  function: (identifier) @_function
  arguments: (argument_list
    (_)
    .
    (_)
    .
    (_)
    .
    [
      (string_literal
        (string_content) @injection.content)
      (concatenated_string
        (string_literal
          (string_content) @injection.content))
    ]))
  (#match? @_function "^mvwscanw$")
)

; TODO: add when asm is added
; (gnu_asm_expression assembly_code: (string_literal) @injection.content
; ;
; )
; (gnu_asm_expression assembly_code: (concatenated_string (string_literal) @injection.content)
; ;
; )
; inherits: c

; TODO(amaanq): uncomment/add when I add asm support
; (ms_asm_block "{" _ @asm "}")
;
; ((asm_specifier (string_literal) @asm)
;   (#offset! @asm 0 1 0 -1))
;
; ((asm_statement (string_literal) @asm)
;   (#offset! @asm 0 1 0 -1))
