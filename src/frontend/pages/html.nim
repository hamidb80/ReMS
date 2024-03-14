import std/[tables, strutils, os, times]

import karax/[vdom, karaxdsl]

import ../utils/ui
import ./deps
import ../../common/package
import ../../backend/routes


func normalizeOsName(url: string): string =
  for ch in url:
    result.add:
      case ch
      of 'a'..'z', 'A'..'Z', '0'..'9', '_', '-', '.': ch
      else: '-'

proc localize(url: string): string =
  getDistUrl normalizeOsName url.splitPath.tail

proc resolveLib(key: string): string =
  assert key in extdeps
  getDistUrl "lib" / key

proc extLink(rel, url: string): VNode =
  buildHtml link(rel = rel, href = url)

proc extCss(url: string): VNode =
  buildHtml extLink("stylesheet", url)

proc extJs(url: string, defered: bool = false): VNode =
  result = buildHtml script(src = url, `defer` = defered)

proc commonHead(pageTitle: string, extra: openArray[VNode]): VNode =
  buildHtml head:
    meta(charset = "UTF-8")
    meta(name = "viewport", content = "width=device-width, initial-scale=1.0")

    title: text pageTitle
    extLink "icon", localize "./favicon.png"

    # JS libraries
    extJs resolveLib"lib.konva.js"
    extJs resolveLib"lib.katex.js"
    extJs resolveLib"lib.axios.js"

    # UI libraries
    extCss resolveLib"lib.katex.css"
    extCss resolveLib"theme.bootstrap.css"
    extCss extdeps["icons.boostrap.css"]
    extCss "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css"

    # font
    link(rel = "preconnect", href = "https://fonts.googleapis.com")
    link(rel = "preconnect", href = "https://fonts.gstatic.com",
        crossorigin = "")
    extCss extdeps["fonts.google.css"]

    # custom
    extCss localize apv"./custom.css"

    for e in extra: 
      e

proc commonPage(title: string, deps: openarray[Vnode]): VNode =
  buildHtml html:
    commonHead title, deps
    body(class = "bg-light"):
      tdiv(id = "ROOT")

# ----- pages -----

proc tags: VNode =
  commonPage "tag manager", [
      extJs(localize apv"./script-tags.js", true)]

proc boardEdit: VNode =
  commonPage "Board", [
      extJs resolveLib"lib.font-observer.js",
      extJs(localize apv"./script-board.js", true)]

proc notePreview: VNode =
  commonPage "Note preview", [
      extJs(localize apv"./note-preview.js", true)]

proc noteEditor: VNode =
  commonPage "editor", [
      extJs(localize apv"./script-editor.js", true)]

proc explore*: VNode =
  commonPage "explore", [
      extJs(localize apv"./script-explore.js", true)]

proc login*: VNode =
  commonPage "login", [
      extJs(localize apv"./script-login.js", true)]

proc palette*: VNode =
  commonPage "login", [
      extJs(localize apv"./palette-studio.js", true)]

proc index: VNode =
  func tryBtnLink(link: string): VNode =
    buildHtml:
      a(class = "btn btn-primary", href = link):
        text "Open"

  func blockk(title, desc, icon, link: string): VNode =
    buildHtml:
      tdiv(class = "p-3 my-4 card"):
        tdiv(class = "card-body d-flex flex-row justify-content-between"):
          tdiv(class = "d-flex flex-column align-items-center justify-content-evenly me-3 minw-30"):
            h3(class = "text-center"):
              text title
            img(src = getDistUrl icon)

            if link != "":
              tdiv(class = "mt-2"):
                tryBtnLink link

          tdiv:
            text desc

  buildHtml html:
    commonHead "intro", []

    body(class = "bg-light"):
      h1(class = "my-4 text-center w-100"):
        italic(class = "text-primary"):
          bold:
            text "Remember"
        text " Better With Us"

      h3(class = "mt-4 mb-2 text-center w-100"):
        text "Actions"
      tdiv(class = "d-flex flex-wrap justify-content-evenly"):
        blockk "Explore", "", "icons/planet.svg", get_explore_url()
        blockk "Tags", "", "icons/tag.svg", get_tags_url()
        blockk "change colors", "", "icons/palette.svg", get_palette_studio_url()
        blockk "Login", "", "icons/user.svg", get_login_url()

      h3(class = "mt-4 mb-2 text-center w-100"):
        text "parts"
      tdiv(class = "d-flex flex-wrap justify-content-evenly"):
        blockk "Notes", "", "icons/pen-writing-on-paper.svg", ""
        blockk "Files", "", "icons/inbox-archive.svg", ""
        blockk "Boards", "", "icons/share-circle.svg", ""

      h3(class = "mt-4 mb-2 text-center w-100"):
        text "Features"
      tdiv(class = "d-flex flex-wrap justify-content-evenly"):
        blockk "Save your Time", "", "icons/clock-square.svg", ""
        blockk "Remember", "", "icons/repeat.svg", ""
        blockk "Open Source", "", "icons/hand-heart.svg", "https://github.com/hamidb80/rems"

      footer(class = "app-footer card text-white bg-primary rounded-0"):
        tdiv(class = "card-body"):
          h4(class = "card-title"):
            text "Still waiting?"

          p(class = "card-text"):
            text "WTF man? Just click on `explore` and have fun remembering!"

        tdiv(class = "card-footer text-center"):
          text "created with passion "
          icon "fa-heart"

        tdiv(class = "card-footerer text-center p-1"):
            text "version "
            text packageVersion
            text " - built at "
            text $now()


# -----

func `$$`(vn: VNode): string =
  ## attach HTML 5 header
  "<!DOCTYPE html>\n" & $vn

when isMainModule:
  writeFile apv "./dist/index.html", $$index()
  writeFile apv "./dist/login.html", $$login()
  writeFile apv "./dist/tags.html", $$tags()
  writeFile apv "./dist/explore.html", $$explore()
  writeFile apv "./dist/board.html", $$boardEdit()
  writeFile apv "./dist/note-preview.html", $$notePreview()
  writeFile apv "./dist/editor.html", $$noteEditor()
  writeFile apv "./dist/palette.html", $$palette()
