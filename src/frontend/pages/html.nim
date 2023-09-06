import std/[strutils, os, httpclient, sequtils]
import karax/[vdom, karaxdsl]
import ../../backend/routes

# ----- aliases -----

proc download(url, path: string) =
  try:
    var
      client = newHttpClient()
      bin = client.getContent url # , path

    writeFile path, bin
    echo "✅ Downloaded ", url

  except:
    echo "⭕ Failed to download ", url
    echo "Reason: ", getCurrentExceptionMsg()


const
  saveDir = "./dist/"
  cannot = ["font-awesome", "katex.min.css", "bootstrap-icons"]


func normalizeOsName(url: string): string =
  for ch in url:
    result.add:
      case ch
      of 'a'..'z', 'A'..'Z', '0'..'9', '_', '-', '.': ch
      else: '-'

proc localize(url: string): string =
  let
    fileName = normalizeOsName url.splitPath.tail
    filePath = saveDir & filename
    loadPath = getDistUrl fileName
    isFromInternet = url.startsWith "http"

  if isFromInternet:
    if defined localdev:
      discard existsOrCreateDir saveDir

      if cannot.anyIt(it in url): url
      else:
        if not fileExists filePath:
          download url, filePath
        loadPath
    else: url
  else: loadPath

proc extLink(rel, url: string): VNode =
  buildHtml link(rel = rel, href = localize url)

proc extCss(url: string): VNode =
  buildHtml extLink("stylesheet", url)

proc extJs(url: string, defered: bool = false): VNode =
  result = buildHtml script(src = localize url, `defer` = defered)

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
    extCss "https://fonts.googleapis.com/css2?family=Vazirmatn:wght@400&display=swap"

    # custom
    extCss "./custom.css"

    for e in extra: e

proc commonPage(title: string, deps: openarray[Vnode]): VNode =
  buildHtml html:
    commonHead title, deps
    body(class = "bg-light"):
      tdiv(id = "ROOT")

# ----- pages -----

proc boards: VNode =
  commonPage "ReMS - Remembering Manangement System", [
      extJs("./script-boards-list.js", true)]

proc board: VNode =
  commonPage "Board", [
      extJs("./script-board.js", true)]

proc assets: VNode =
  commonPage "asset manager", [
      extJs("./script-assets.js", true)]

proc tags: VNode =
  commonPage "tag manager", [
      extJs("./script-tags.js", true)]

proc editor: VNode =
  commonPage "editor", [
      extJs("./script-editor.js", true)]

proc notes_list*: VNode =
  commonPage "note list", [
      extJs("./script-note-list.js", true)]

proc index: VNode =
  buildHtml html:
    commonHead "editor", []

    body(class = "bg-light"):
      h1(class = "my-4 text-center w-100"):
        text "Bringing Tools🛠 Together🤝!"

      tdiv(class = "d-flex flex-wrap justify-content-around my-4"):
        a(class = "p-4 border rounded m-4 bg-white", href = get_notes_url()):
          text "Notes ✒"

        a(class = "p-4 border rounded m-4 bg-white", href = get_assets_url()):
          text "Assets 📦"

        a(class = "p-4 border rounded m-4 bg-white", href = get_boards_url()):
          text "Board 👨‍🏫"

        a(class = "p-4 border rounded m-4 bg-white", href = get_tags_url()):
          text "tags 🏷"

# -----

when isMainModule:
  copyFileToDir "./src/frontend/custom.css", "./dist"
  copyFileToDir "./assets/icon.png", "./dist"
  writeFile "./dist/index.html", $index()
  writeFile "./dist/boards.html", $boards()
  writeFile "./dist/board.html", $board()
  writeFile "./dist/assets.html", $assets()
  writeFile "./dist/tags.html", $tags()
  writeFile "./dist/editor.html", $editor()
  writeFile "./dist/notes_list.html", $notes_list()
