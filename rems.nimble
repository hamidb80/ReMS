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
requires "prettyvec"

requires "mummy" # 0.3.2
requires "jsony" # 1.1.5
requires "ponairi" # 0.3.2
requires "waterpark" # 0.1.3
requires "quickjwt" # 0.2.1
requires "bale"

requires "karax" # 1.3.0
# requires "urlon"


# Tasks
import std/[os, strutils, strformat]


task prepare, "creates the directory ./dist used for final output":
  mkdir "./resources"
  mkdir "./dist"

task make, "make all":
  exec "nimble html"
  exec "nimble genb"
  exec "nimble genas"
  exec "nimble gened"
  exec "nimble gentg"
  exec "nimble genex"

task genex, "":
  exec fmt"nim -d:nimExperimentalAsyncjsThen js -o:./dist/script-explore.js src/frontend/pages/explore"

task genb, "":
  exec fmt"nim -d:nimExperimentalAsyncjsThen js -o:./dist/script-board.js src/frontend/pages/board"

task genas, "":
  exec fmt"nim -d:nimExperimentalAsyncjsThen js -o:./dist/script-assets.js src/frontend/pages/assets"

task gentg, "":
  exec fmt"nim -d:nimExperimentalAsyncjsThen js -o:./dist/script-tags.js src/frontend/pages/tags"

task gened, "":
  exec fmt"nim -d:nimExperimentalAsyncjsThen js -o:./dist/script-editor.js src/frontend/pages/editor/app"

task html, "generate index.html ./dist":
  cpfile "./src/frontend/custom.css", "./dist/custom.css"
  cpDir "./assets/", "./dist/"
  exec fmt"nim -d:frontend r src/frontend/pages/html.nim"

task serv, "run server":
  exec fmt"nim --mm:arc --threads:on -d:ssl r ./src/backend/server.nim"
