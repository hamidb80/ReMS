import std/[strutils, os, httpclient, sequtils]
import karax/[vdom, karaxdsl]
import ../../common/path
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
    loadPath =  "" #getDistUrl fileName
    isFromInternet = url.startsWith "http"

  if isFromInternet:
    when defined localdev:
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
  result = buildHtml script(src = localize url)
  if defered:
    result.setAttr "defer"

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

    # UI libraries
    extCss "https://bootswatch.com/5/litera/bootstrap.min.css"
    extCss "https://cdn.jsdelivr.net/npm/katex@0.16.8/dist/katex.min.css"
    extCss "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css"
    extCss "https://cdn.jsdelivr.net/npm/bootstrap-icons@1.10.5/font/bootstrap-icons.css"

    # font
    link(rel = "preconnect", href = "https://fonts.googleapis.com")
    link(rel = "preconnect", href = "https://fonts.gstatic.com",
        crossorigin = "")
    extCss "https://fonts.googleapis.com/css2?family=Vazirmatn:wght@400&display=swap"

    # custom
    extCss "./custom.css"

    for e in extra: e

# ----- pages -----

proc board: VNode =
  buildHtml html:
    commonHead "ReMS - Remembering Manangement System", [
      extJs "https://unpkg.com/konva@9/konva.min.js",
      extJs "https://unpkg.com/hotkeys-js/dist/hotkeys.min.js",
      extJs("./script.js", true)]

    body(class = "overflow-hidden"):
      tdiv(id = "app")

proc assets: VNode =
  buildHtml html:
    commonHead "asset manager", [
      extJs("./script-assets.js", true),
      extJs "https://cdn.jsdelivr.net/npm/axios/dist/axios.min.js"]

    body(class = "bg-light"):
      tdiv(id = "ROOT")

proc tags: VNode =
  buildHtml html:
    commonHead "tag manager", [
      extJs("./script-tags.js", true)]

    body(class = "bg-light"):
      tdiv(id = "ROOT")

proc editor: VNode =
  buildHtml html:
    commonHead "editor", [
      extJs("./script-editor.js", true),
      extJs "https://cdn.jsdelivr.net/npm/marked/marked.min.js"]

    body(class = "bg-light"):
      tdiv(id = "ROOT")


# -----

when isMainModule:
  copyFileToDir "./src/frontend/custom.css", "./dist"
  writeFile "./dist/board.html", $board()
  writeFile "./dist/assets.html", $assets()
  writeFile "./dist/tags.html", $tags()
  writeFile "./dist/editor.html", $editor()

else:
  const
    boardPageStr* = staticRead projectHome / "./dist/board.html"
    assetsPageStr* = staticRead projectHome / "./dist/assets.html"
    tagsPageStr* = staticRead projectHome / "./dist/tags.html"
    editorPageStr* = staticRead projectHome / "./dist/editor.html"
