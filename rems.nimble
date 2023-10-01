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
requires "cookiejar" # 0.3.0
# requires "bale"

requires "karax" # 1.3.0
# requires "urlon"


# Tasks
import std/[os, strutils, strformat]


task prepare, "creates the directory ./dist used for final output":
  mkdir "./resources"
  mkdir "./dist"

task db, "init db":
  exec "nim r src/backend/utils/db_init.nim"

task make, "make all":
  exec "nimble html"
  exec "nimble genb"
  exec "nimble gened"
  exec "nimble gentg"
  exec "nimble genex"
  exec "nimble genlg"

task genlg, "":
  exec fmt"nim -d:nimExperimentalAsyncjsThen js -o:./dist/script-login.js src/frontend/pages/login"

task genex, "":
  exec fmt"nim -d:nimExperimentalAsyncjsThen js -o:./dist/script-explore.js src/frontend/pages/explore"

task genb, "":
  exec fmt"nim -d:nimExperimentalAsyncjsThen js -o:./dist/script-board.js src/frontend/pages/board"

task gentg, "":
  exec fmt"nim -d:nimExperimentalAsyncjsThen js -o:./dist/script-tags.js src/frontend/pages/tags"

task gened, "":
  exec fmt"nim -d:nimExperimentalAsyncjsThen js -o:./dist/script-editor.js src/frontend/pages/editor/app"

task html, "generate index.html ./dist":
  cpfile "./src/frontend/custom.css", "./dist/custom.css"
  cpDir "./assets/", "./dist/"
  exec fmt"nim -d:frontend r src/frontend/pages/html.nim"

task bot, "bale box":
  putEnv "BALE_BOT_TOKEN", readfile "bot.token"
  exec "nim -d:bale_debug -d:ssl r src/backend/bot"

task serv, "run server":
  # sudo apt-get install libssl-dev
  exec fmt"""nim --d:ssl --passL:"-lcrypto"  --mm:arc --threads:on -d:ssl r ./src/backend/server.nim"""
