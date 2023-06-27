# Package

version       = "0.0.1"
author        = "hamidb80"
description   = "A new awesome nimble package"
license       = "MIT"
srcDir        = "src"
bin           = @["graphit"]


# Dependencies

requires "nim >= 1.6.12"

task script, "generate script.js file in ./dist":
  exec "nim js --hints:off -o:./dist/script.js src/main.nim"

task html, "generate index.html ./dist":
  exec "nim r src/ui.nim"
