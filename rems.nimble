# Package

version       = "0.0.1"
author        = "hamidb80"
description   = "Remebering Management System"
license       = "MIT"
srcDir        = "src"
bin           = @["rms"]


# Dependencies

requires "nim >= 1.6.12"
requires "macroplus >= 0.2.5"
requires "karax == 1.3.0"
# requires "urlon"
requires "caster"
requires "uuid4"
requires "questionable"
requires "prettyvec"


# Tasks
import std/[os, strutils, strformat]

proc getArgs: string = 
  let 
    paramsAll = commandLineParams()
    startIndex = paramsAll.find("html")
    params = paramsAll[startIndex+1 .. ^1]
  result = params.join " "


task genb, "generate script.js file in ./dist":
  exec "nim -d:nimExperimentalAsyncjsThen js -o:./dist/script.js src/frontend/pages/board"

task genas, "generate script.js file in ./dist":
  exec "nim -d:nimExperimentalAsyncjsThen js -o:./dist/script-assets.js src/frontend/pages/assets"

task gentg, "generate script.js file in ./dist":
  exec "nim -d:nimExperimentalAsyncjsThen js -o:./dist/script-tags.js src/frontend/pages/tags"

task html, "generate index.html ./dist":
  # -d:localdev 
  exec fmt"nim {getArgs()} -d:ssl r src/frontend/pages/html.nim "
