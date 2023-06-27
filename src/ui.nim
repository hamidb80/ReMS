import std/[strformat, dom, jsconsole]
# import karax/[karaxdsl, vdom, vstyles, ]
import karax/[vstyles]
include karax/prelude
import utils


# --- components ---
func icon(class: string): VNode =
  buildHtml:
    bold(class = "fa-solid fa-" & class)

func konva(id: cstring): VNode =
  verbatim fmt"""
    <div id="{id}"></div>
  """

# --- views ---
template winel: untyped =
  window.document.body

template iff(cond, val): untyped =
  if cond: val
  else: default type val

var sidebarWidth = 400
proc createDom*: VNode =
  let freeze = winel.onmousemove != nil
  echo "just updated"

  buildHtml:
    tdiv(class = "karax"):
      main(class = "board-wrapper border border-dark rounded overflow-hidden"):
        konva "board"

      aside(class = "side-bar position-absolute shadow-sm border bg-white h-100 d-flex flex-row " &
          iff(freeze, "user-select-none"), style = style(StyleAttr.width,
              fmt"{sidebarWidth}px")):

        tdiv(class = "extender bg-secondary h-100"):
          proc onMouseDown(ev: Event, n: VNode) =
            winel.onmousemove = proc(e: Event as MouseEvent) {.caster.} =
              let amount = window.innerWIdth - e.clientX
              sidebarWidth = max(amount, 300)
              redraw()

            winel.addEventListener "mouseup", proc(e: Event) =
              winel.onmousemove.reset

        tdiv(class = "d-flex flex-column w-100"):
          header(class = "nav nav-tabs d-flex flex-row justify-content-between"):

            tdiv(class = "nav-item"):
              span(class = "nav-link active cursor"):
                text "Messages "
                icon "message"

            tdiv(class = "nav-item"):
              span(class = "nav-link cursor"):
                text "Settings "
                icon "wrench"

          main(class = "p-4 content-wrapper"):
            for i in 1..20:
              tdiv(class = "card mb-4"):
                tdiv(class = "card-body"):
                  h4(class = "card-title"):
                    text "Card title"
                  h6(class = "card-subtitle mb-2 text-muted"):
                    text "Card subtitle"
                  p(class = "card-text"):
                    text """Some quick example text to build on the card title and make up the bulk of the card's content."""
                  a(class = "card-link", href = "#"):
                    text "Card link"
                  a(class = "card-link", href = "#"):
                    text "Another link"


func index*(t = "RMS - Remembering Manangement System"): VNode =
  buildHtml:
    html(lang = "en"):
      head:
        meta(charset = "UTF-8")
        meta(content = "width=device-width, initial-scale=1.0",
            name = "viewport")
        title:
          text t
        script(src = "https://unpkg.com/konva@9/konva.min.js")
        script(src = "https://unpkg.com/hotkeys-js/dist/hotkeys.min.js")
        script(src = "./page.js", `defer` = "")
        script(src = "./script.js", `defer` = "")
        link(rel = "stylesheet", href = "https://bootswatch.com/5/flatly/bootstrap.min.css")
        link(rel = "stylesheet", href = "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css")
        link(rel = "stylesheet", href = "./custom.css")
      body:
        tdiv(id = "app")


when isMainModule:
  writeFile "./dist/index.html", $index()
