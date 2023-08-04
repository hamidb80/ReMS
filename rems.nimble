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

# Tasks
import std/[os, strutils, strformat]

proc getArgs: string = 
  let 
    paramsAll = commandLineParams()
    startIndex = paramsAll.find("html")
    params = paramsAll[startIndex+1 .. ^1]
  result = params.join " "


task genb, "generate script.js file in ./dist":
  exec "nim -d:nimExperimentalAsyncjsThen js -o:./dist/script.js src/pages/board"

task genas, "generate script.js file in ./dist":
  exec "nim -d:nimExperimentalAsyncjsThen js -o:./dist/script-assets.js src/pages/assets"

task gentg, "generate script.js file in ./dist":
  exec "nim -d:nimExperimentalAsyncjsThen js -o:./dist/script-tags.js src/pages/tags"

task html, "generate index.html ./dist":
  # -d:localdev 
  exec fmt"nim {getArgs()} -d:ssl r src/pages/html.nim "