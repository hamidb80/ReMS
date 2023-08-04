import std/[strutils, os, httpclient, sequtils]
import karax/[vdom, karaxdsl]

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
  loadDir = "./"
  cannot = ["font-awesome"]

proc localize(url: string): string =
  let
    fileName = url.splitPath.tail
    filePath = saveDir & filename
    loadPath = loadDir & fileName

  when not defined localDev: url
  else:
    discard existsOrCreateDir saveDir

    if cannot.anyIt(it in url): url
    else:
      if (url.startsWith "http") and (not fileExists filePath):
        download url, filePath

      loadPath

proc extCss(url: string): VNode =
  buildHtml link(rel = "stylesheet", href = localize url)

proc extJs(url: string, defered: bool = false): VNode =
  result = buildHtml script(src = localize url)
  if defered:
    result.setAttr "defer"

proc commonHead(pageTitle: string, extra: openArray[VNode]): VNode =
  buildHtml head:
    meta(charset = "UTF-8")
    meta(name = "viewport", content = "width=device-width, initial-scale=1.0")
    title: text pageTitle

    extJs "https://unpkg.com/konva@9/konva.min.js"
    extJs "https://unpkg.com/hotkeys-js/dist/hotkeys.min.js"

    extCss "https://bootswatch.com/5/litera/bootstrap.min.css"
    extCss "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css"
    extCss "./custom.css"

    for e in extra:
      e

# ----- pages -----

proc index*(pageTitle: string): VNode =
  buildHtml html:
    commonHead pageTitle, [
      extJs("https://unpkg.com/konva@9/konva.min.js"),
      extJs("./script.js", true),
      extJs("https://unpkg.com/hotkeys-js/dist/hotkeys.min.js")]

    body(class = "overflow-hidden"):
      tdiv(id = "app")

proc assets*(pageTitle: string): VNode =
  buildHtml html:
    commonHead pageTitle, [extJs("./script-assets.js", true)]

    body(class = "bg-light"):
      tdiv(id = "ROOT")

proc tags*(pageTitle: string): VNode =
  buildHtml html:
    commonHead pageTitle, [extJs("./script-tags.js", true)]

    body(class = "bg-light"):
      tdiv(id = "ROOT")


when isMainModule:
  echo "🏃 started ..."

  writeFile "./dist/index.html":
    $ index "ReMS - Remembering Manangement System"

  writeFile "./dist/assets.html":
    $ assets "asset manager"

  writeFile "./dist/tags.html":
    $ tags "tag manager"

  echo "👋 asset files are ready!"