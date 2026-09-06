local M = {}

M.testMarkers = {
    "Test",
}

M.TestCaseBak = [[
;; Default Test Case
(function_declaration
  (modifiers
    (annotation) @test.annotation
    (#match? @test.annotation "(^|[.@])Test(\\(|$)"))
  (simple_identifier) @test.name
) @test.definition
]]

M.TestCaseBakkk = [[
(class_declaration
  (modifiers)? @test.class.modifiers
  (class_body
    (function_declaration
    (modifiers
      (annotation) @test.annotation
      (#match? @test.annotation "(^|[.@])Test(\\(|$)"))
    (simple_identifier) @test.name
    ) @test.definition
  )
  (#not-match? @test.class.modifiers "(^|\\s)abstract($|\\s)")
)
]]

M.NameSpace = [[
;; Default Class Name, regecting abstract classes
(class_declaration
  (modifiers)? @namespace.modifiers
  (type_identifier) @namespace.name
  (#not-match? @namespace.modifiers "(^|\\s)abstract($|\\s)")
) @namespace.definition

;; Default Class Name, regecting abstract classes
(class_declaration
  . (type_identifier) @namespace.name
) @namespace.definition
]]

local fukt = [[


;; Unmodified concrete class.
;; The anchor ensures type_identifier is the first named child,
;; meaning there is no modifiers node before it.
(class_declaration
  . (type_identifier) @namespace.name

  )
) @namespace.definition

;; Modified class, excluding abstract classes.
(class_declaration
  . (modifiers) @test.class.modifiers
  (type_identifier) @namespace.name

  (#not-match? @test.class.modifiers "(^|\\s)abstract($|\\s)")
) @namespace.definition

]]

M.TestCase = [[
;; Unmodified concrete class.
;; The anchor ensures type_identifier is the first named child,
;; meaning there is no modifiers node before it.
(class_declaration
  . (type_identifier)
  (class_body
    (function_declaration
      (modifiers
        (annotation) @test.annotation
        (#match? @test.annotation "(^|[.@])Test(\\(|$)"))
      (simple_identifier) @test.name
    ) @test.definition
  )
)

;; Modified class, excluding abstract classes.
(class_declaration
  . (modifiers) @test.class.modifiers
  (type_identifier)
  (class_body
    (function_declaration
      (modifiers
        (annotation) @test.annotation
        (#match? @test.annotation "(^|[.@])Test(\\(|$)"))
      (simple_identifier) @test.name
    ) @test.definition
  )
  (#not-match? @test.class.modifiers "(^|\\s)abstract($|\\s)")
)
]]

return M
