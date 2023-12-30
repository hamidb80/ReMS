import std/[strutils, os, times]

import karax/[vdom, karaxdsl]

import ../utils/ui
import ../../common/package
import ../../backend/routes


func normalizeOsName(url: string): string =
  for ch in url:
    result.add:
      case ch
      of 'a'..'z', 'A'..'Z', '0'..'9', '_', '-', '.': ch
      else: '-'

proc resolveUrl(url: string): string =
  if url.startsWith "http": # is from internet
    url
  else:
    getDistUrl normalizeOsName url.splitPath.tail


proc extLink(rel, url: string): VNode =
  buildHtml link(rel = rel, href = resolveUrl url)

proc extCss(url: string): VNode =
  buildHtml extLink("stylesheet", url)

proc extJs(url: string, defered: bool = false): VNode =
  result = buildHtml script(src = resolveUrl url, `defer` = defered)

proc commonHead(pageTitle: string, extra: openArray[VNode]): VNode =
  buildHtml head:
    meta(charset = "UTF-8")
    meta(name = "viewport", content = "width=device-width, initial-scale=1.0")

    title: text pageTitle
    extLink "icon", "./icon.png"

    # JS libraries
    extJs "https://unpkg.com/konva@9/konva.min.js"
    extJs "https://cdn.jsdelivr.net/npm/katex@0.16.8/dist/katex.min.js"
    extJs "https://cdn.jsdelivr.net/npm/axios/dist/axios.min.js"

    # UI libraries
    extCss "https://bootswatch.com/5/litera/bootstrap.min.css"
    extCss "https://cdn.jsdelivr.net/npm/katex@0.16.8/dist/katex.min.css"
    extCss "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css"
    extCss "https://cdn.jsdelivr.net/npm/bootstrap-icons@1.10.5/font/bootstrap-icons.css"
    # extCss "https://cdnjs.cloudflare.com/ajax/libs/animate.css/4.1.1/animate.min.css"

    # font
    link(rel = "preconnect", href = "https://fonts.googleapis.com")
    link(rel = "preconnect", href = "https://fonts.gstatic.com",
        crossorigin = "")
    extCss "https://fonts.googleapis.com/css2?family=Mooli&family=Vazirmatn:wght@400&family=Ubuntu+Mono&display=swap"

    # custom
    extCss apv"./custom.css"

    for e in extra: e

proc commonPage(title: string, deps: openarray[Vnode]): VNode =
  buildHtml html:
    commonHead title, deps
    body(class = "bg-light"):
      tdiv(id = "ROOT")

# ----- pages -----

proc tags: VNode =
  commonPage "tag manager", [
      extJs(apv"./script-tags.js", true)]

proc boardEdit: VNode =
  commonPage "Board", [
      extJs "https://cdnjs.cloudflare.com/ajax/libs/fontfaceobserver/2.3.0/fontfaceobserver.standalone.js",
      extJs(apv"./script-board.js", true)]

proc notePreview: VNode =
  commonPage "Note preview", [
      extJs(apv"./note-preview.js", true)]

proc noteEditor: VNode =
  commonPage "editor", [
      extJs(apv"./script-editor.js", true)]

proc explore*: VNode =
  commonPage "explore", [
      extJs(apv"./script-explore.js", true)]

proc login*: VNode =
  commonPage "login", [
      extJs(apv"./script-login.js", true)]

proc palette*: VNode =
  commonPage "login", [
      extJs(apv"./palette-studio.js", true)]

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
        blockk "Explore", "", "planet.svg", get_explore_url()
        blockk "Tags", "", "tag.svg", get_tags_url()
        blockk "change colors", "", "palette.svg", get_palette_studio_url()
        blockk "Login", "", "user.svg", get_login_url()

      h3(class = "mt-4 mb-2 text-center w-100"):
        text "parts"
      tdiv(class = "d-flex flex-wrap justify-content-evenly"):
        blockk "Notes", "", "pen-writing-on-paper.svg", ""
        blockk "Files", "", "inbox-archive.svg", ""
        blockk "Boards", "", "share-circle.svg", ""

      h3(class = "mt-4 mb-2 text-center w-100"):
        text "Features"
      tdiv(class = "d-flex flex-wrap justify-content-evenly"):
        blockk "Save your Time", "", "clock-square.svg", ""
        blockk "Remember", "", "repeat.svg", ""
        blockk "Open Source", "", "hand-heart.svg", "https://github.com/hamidb80/rems"

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
  writeFile "./dist/index.html", $$index()
  writeFile "./dist/login.html", $$login()
  writeFile "./dist/tags.html", $$tags()
  writeFile "./dist/explore.html", $$explore()
  writeFile "./dist/board.html", $$boardEdit()
  writeFile "./dist/note-preview.html", $$notePreview()
  writeFile "./dist/editor.html", $$noteEditor()
  writeFile "./dist/palette.html", $$palette()
