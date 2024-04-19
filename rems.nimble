# Package

version       = "0.0.79"
author        = "hamidb80"
description   = "Remebering Management System"
license       = "MIT"
srcDir        = "src"
bin           = @["rems"]


# Dependencies

# openssl  & libssl-dev
requires "nim >= 2.0.0"

requires "checksums" # for Nim 2
requires "htmlparser" # for Nim 2
requires "db_connector >= 0.1.0" # for Nim 2

requires "macroplus >= 0.2.5"
requires "caster"
requires "questionable"
requires "prettyvec"

requires "https://hamgit.ir/hr.bolouri/zippy" # it is the dependency of mummy and the PASS that I use have some problem downloading it ...

requires "mummy" # 0.3.2
requires "jsony" # 1.1.5
requires "ponairi" # 0.3.2
requires "waterpark == 0.1.6"
requires "quickjwt" # 0.2.1
requires "cookiejar" # 0.3.0
requires "bale" # 1.0.0
requires "karax == 1.3.0"


# Tasks
import std/[os, strutils, strformat]


task genpfp, "":
  exec fmt"nim -d:nimExperimentalAsyncjsThen js -o:./dist/script-profile-{version}.js src/frontend/pages/profile"

task gennp, "":
  exec fmt"nim -d:nimExperimentalAsyncjsThen js -o:./dist/note-preview-{version}.js src/frontend/pages/note_preview"

task genex, "":
  exec fmt"nim -d:nimExperimentalAsyncjsThen js -o:./dist/script-explore-{version}.js src/frontend/pages/explore"

task genb, "":
  exec fmt"nim -d:nimExperimentalAsyncjsThen js -o:./dist/script-board-{version}.js src/frontend/pages/board"

task gened, "":
  exec fmt"nim -d:nimExperimentalAsyncjsThen js -o:./dist/script-editor-{version}.js src/frontend/pages/editor/app"

task ddeps, "downloads external dependencies":
  exec "nim -d:ssl -d:allInternal r src/frontend/deps.nim"

task html, "generate index.html ./dist":
  exec fmt"nim -f -d:frontend r src/frontend/pages/html.nim"

task dist, "copy files to dist directory":
  cpfile "./src/frontend/custom.css", fmt"./dist/custom-{version}.css"
  cpDir "./assets/", "./dist/"

task make, "make all":
  ddeps_task()
  html_task()
  dist_task()
  genb_task()
  gened_task()
  gennp_task()
  genex_task()
  genpfp_task()


task prepare, "define envorment vars only for test":
  mkdir "./dist"
  mkdir "./bin"
  mkdir "./assets/lib"
  mkdir getEnv("APP_DIR") / "resources"

task db, "init db":
  exec "nim r src/backend/utils/db_init.nim"

task bot, "bale bot":
  exec "nim -d:bale_debug -d:ssl r src/backend/bot"

task go, "runs server + bot":
  exec """nim --mm:arc -d:ssl --d:loginTestUser --passL:"-lcrypto" r ./src/backend/main.nim"""

task done, "runs server + bot":
  exec """nim --mm:arc -d:ssl --passL:"-lcrypto" -o:./bin/main.exe c ./src/backend/main.nim"""
