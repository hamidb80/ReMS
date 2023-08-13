# Package

version       = "0.0.1"
author        = "hamidb80"
description   = "Remebering Management System"
license       = "MIT"
srcDir        = "src"
bin           = @["rems"]


# Dependencies

requires "nim >= 1.6.14"

requires "macroplus >= 0.2.5"
requires "caster"
requires "uuid4"
requires "questionable"

requires "mummy"
requires "poinari"
requires "lowdb"
requires "quickjwt"
requires "bale"

requires "karax == 1.3.0"
requires "prettyvec"
# requires "urlon"


# Tasks
import std/[os, strutils, strformat]

task genb, "generate script.js file in ./dist":
  exec "nim -d:nimExperimentalAsyncjsThen js -o:./dist/script.js src/frontend/pages/board"

task genas, "generate script.js file in ./dist":
  exec "nim -d:nimExperimentalAsyncjsThen js -o:./dist/script-assets.js src/frontend/pages/assets"

task gentg, "generate script.js file in ./dist":
  exec "nim -d:nimExperimentalAsyncjsThen js -o:./dist/script-tags.js src/frontend/pages/tags"

task gened, "generate script.js file in ./dist":
  exec "nim -d:nimExperimentalAsyncjsThen js -o:./dist/script-editor.js src/frontend/pages/editor/app"

task html, "generate index.html ./dist":
  exec fmt"nim -d:ssl r src/frontend/pages/html.nim"

task localhtml, "generate index.html ./dist":
  exec fmt"nim -d:ssl -d:localdev r src/frontend/pages/html.nim"
