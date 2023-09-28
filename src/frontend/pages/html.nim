import std/[strutils, os]

import karax/[vdom, karaxdsl]

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
    extJs "https://unpkg.com/hotkeys-js/dist/hotkeys.min.js"
    extJs "https://cdn.jsdelivr.net/npm/katex@0.16.8/dist/katex.min.js"
    extJs "https://cdn.jsdelivr.net/npm/marked/marked.min.js"
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
    extCss "./custom.css"

    for e in extra: e

proc commonPage(title: string, deps: openarray[Vnode]): VNode =
  buildHtml html:
    commonHead title, deps
    body(class = "bg-light"):
      tdiv(id = "ROOT")

# ----- pages -----

proc tags: VNode =
  commonPage "tag manager", [
      extJs("./script-tags.js", true)]

proc boardEditor: VNode =
  commonPage "Board", [
      extJs "https://cdnjs.cloudflare.com/ajax/libs/fontfaceobserver/2.3.0/fontfaceobserver.standalone.js",
      extJs("./script-board.js", true)]

proc noteEditor: VNode =
  commonPage "editor", [
      extJs("./script-editor.js", true)]

proc explore*: VNode =
  commonPage "explore", [
      extJs("./script-explore.js", true)]

proc login*: VNode =
  commonPage "login", [
      extJs("./script-login.js", true)]

proc index: VNode =
  func tryBtnLink(link: string): VNode =
    buildHtml:
      a(class = "btn btn-primary", href = link):
        text "Open"

  func blockk(title, icon, link: string): VNode =
    buildHtml:
      tdiv(class = "p-3 my-4 w-40 card"):
        tdiv(class = "card-body d-flex flex-row justify-content-between"):
          tdiv(class = "d-flex flex-column align-items-center justify-content-evenly me-3 minw-30"):
            h3(class = "text-center"):
              text title
            img(src = getDistUrl icon)

            if link != "":
              tdiv(class = "mt-2"):
                tryBtnLink link

          tdiv:
            text """
                Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor
                 incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam,
                  quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea
            """

  buildHtml html:
    commonHead "intro", []

    body(class = "bg-light"):
      h1(class = "my-4 text-center w-100"):
        italic(class = "text-primary"):
          bold:
            text "Remember"
        text " Better With Us"

      h3(class = "mt-4 mb-2 text-center w-100"):
        text "Features"
      tdiv(class = "d-flex flex-wrap justify-content-evenly"):
        blockk "Explore", "planet.svg", get_explore_url()
        blockk "Files", "inbox-archive.svg", ""
        blockk "Tags", "tag.svg", get_tags_url()
        blockk "Notes", "pen-writing-on-paper.svg", ""
        blockk "Boards", "share-circle.svg", ""
        blockk "Save your Time", "clock-square.svg", ""

      h3(class = "mt-4 mb-2 text-center w-100"):
        text "Coming Soon ..."
      tdiv(class = "d-flex flex-wrap justify-content-evenly"):
        blockk "Login", "user.svg", get_login_url()
        blockk "Built-in Remembering Utils", "repeat.svg", ""
        blockk "It's Open Source", "hand-heart.svg", ""


      footer(class = "app-footer card text-white bg-primary rounded-0"):
        tdiv(class = "card-body"):
          h4(class = "card-title"):
            text "Primary card title"
          p(class = "card-text"):
            text """
  Some quick example text to build on the card title and make up the bulk of the
  card's content."""

        tdiv(class = "card-footer text-center"):
          text "created with passion"


# -----

when isMainModule:
  writeFile "./dist/index.html", $index()
  writeFile "./dist/login.html", $login()
  writeFile "./dist/tags.html", $tags()
  writeFile "./dist/explore.html", $explore()
  writeFile "./dist/board.html", $boardEditor()
  writeFile "./dist/editor.html", $noteEditor()
