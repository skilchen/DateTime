# Package

version       = "0.1.0"
author        = "skilchen"
description   = "DateTime types and operations"
license       = "MIT"

# bin           = @["DateTime"]

# Dependencies

requires "nim >= 0.17.0"

task tests, "Run some DateTime examples and tests":
  exec "nim c -r DateTime"

task tests_js, "Run some DateTime examples and tests using the js backend":
  exec "nim js -d:nodejs -r DateTime"

task module_doc, "generate the internal documentation for the DateTime module"
  exec nim doc DateTime