import std/[tables, os, times]

import karax/[vdom, karaxdsl]

import ../deps
import ../../common/package
import ../../backend/urls
import ../components/simple


func normalizeOsName(url: string): string =
  for ch in url:
    result.add:
      case ch
      of 'a'..'z', 'A'..'Z', '0'..'9', '_', '-', '.': ch
      else: '-'

proc localize(url: string): string =
  dist_url normalizeOsName url.splitPath.tail

proc resolveLib(key: string): string =
  assert key in extdeps
  dist_url "lib" / key

proc extLink(rel, url: string): VNode =
  buildHtml link(rel = rel, href = url)

proc extCss(url: string): VNode =
  buildHtml extLink("stylesheet", url)

proc extJs(url: string, defered: bool = false): VNode =
  buildHtml script(src = url, `defer` = defered)

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
    extCss resolveLib"icons.boostrap.css"
    extCss resolveLib"icons.fontawesome.css"

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

proc profile*: VNode =
  commonPage "profile", [
      extJs(localize apv"./script-profile.js", true)]

# -----

func `$$`(vn: VNode): string =
  ## attach HTML 5 header
  "<!DOCTYPE html>\n" & $vn

when isMainModule:
  writeFile apv "./dist/tags.html", $$tags()
  writeFile apv "./dist/explore.html", $$explore()
  writeFile apv "./dist/board.html", $$boardEdit()
  writeFile apv "./dist/note-preview.html", $$notePreview()
  writeFile apv "./dist/editor.html", $$noteEditor()
