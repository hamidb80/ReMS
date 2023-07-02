import std/[strformat, strutils, sugar, lenientops]
import std/[dom, jsconsole]
import karax/[karaxdsl, vdom, vstyles, karax]
import utils, conventions, browser


# --- components ---

func icon(class: string): VNode =
  buildHtml:
    bold(class = "fa-solid fa-" & class)

func konva(id: cstring): VNode =
  verbatim fmt"""
    <div id="{id}"></div>
  """

func invisibleText: Vnode =
  ## used to fix inconsistent UI behaviours
  buildHtml:
    span(class = "invisible"):
      text "i"


# --- views ---

type
  State = enum
    BookView
    MessagesView
    PropertiesView

# TODO: develop ncss
const
  defaultWidth = 500
  ciriticalWidth = 400
  minimizeWidth = 260

var
  sidebarWidth = defaultWidth
  page = 1
  state = BookView


proc changeStateGen(to: State): proc =
  proc =
    state = to

proc changePdfPageGen(updater: int -> int): proc =
  proc =
    page = updater page
    redraw()

proc isMaximized: bool =
  sidebarWidth >= window.innerWidth * 2/3

proc maximize =
  sidebarWidth =
    if isMaximized(): defaultWidth
    else: window.innerWidth
  redraw()

proc createDom*(): VNode =
  let freeze = winel.onmousemove != nil
  echo "just updated"

  buildHtml:
    tdiv(class = "karax"):
      main(class = "board-wrapper overflow-hidden h-100 w-100"):
        konva "board"

      footer(class = "regions position-absolute bottom-0 left-0 w-100 bg-light border-top border-secondary"):
        discard

      aside(class = "tool-bar btn-group-vertical position-absolute bg-light border border-secondary border-start-0 rounded-right"):
        button(class = "btn invisible p-0")

        button(class = "btn btn-outline-primary border-0 px-3 py-4"):
          icon "download fa-lg"

        button(class = "btn btn-outline-primary border-0 px-3 py-4"):
          icon "crop-simple fa-lg"

        button(class = "btn btn-outline-primary border-0 px-3 py-4"):
          icon "expand fa-lg"

        button(class = "btn btn-outline-primary border-0 px-3 py-4"):
          icon "vector-square fa-lg"

        button(class = "btn invisible p-0")

      aside(class = "side-bar position-absolute shadow-sm border bg-white h-100 d-flex flex-row " &
          iff(freeze, "user-select-none ") & iff(sidebarWidth < ciriticalWidth,
              "icons-only "),
          style = style(StyleAttr.width, fmt"{sidebarWidth}px")):

        tdiv(class = "extender h-100 btn btn-light p-0"):
          proc onMouseDown =
            winel.onmousemove = proc(e: Event as MouseEvent) {.caster.} =
              sidebarWidth = max(window.innerWidth - e.x, minimizeWidth)
              redraw()

            winel.onmouseup = proc(e: Event) =
              reset winel.onmousemove
              reset winel.onmouseup

        tdiv(class = "d-flex flex-column w-100"):
          header(class = "nav nav-tabs d-flex flex-row justify-content-between align-items-end bg-light mb-2"):

            tdiv(class = "d-flex flex-row"):
              tdiv(class = "nav-item", onclick = changeStateGen MessagesView):
                span(class = "nav-link px-3 pointer" &
                    iff(state == MessagesView, " active")):
                  span(class = "caption"):
                    text "Messages "
                  icon "message"

              tdiv(class = "nav-item", onclick = changeStateGen BookView):
                span(class = "nav-link px-3 pointer" &
                    iff(state == BookView, " active")):
                  span(class = "caption"):
                    text "Books "
                  icon "book"

              tdiv(class = "nav-item", onclick = changeStateGen PropertiesView):
                span(class = "nav-link px-3 pointer" &
                  iff(state == PropertiesView, " active")):
                  span(class = "caption"):
                    text "Properties "
                  icon "circle-info"

            tdiv(class = "nav-item d-flex flex-row px-2"):
              span(class = "nav-link px-1 pointer", onclick = maximize):
                invisibleText()

                icon(
                    if isMaximized(): "window-minimize"
                    else: "window-maximize")

          main(class = "p-4 content-wrapper"):
            if state == BookView:
              tdiv(class = "pagination d-flex align-items-center mb-3"):

                tdiv(class = "page-item pointer",
                    onclick = changePdfPageGen (a) => pred a):
                  icon "chevron-left page-link"

                input(type = "number", id = "page-number-input",
                  class = "form-control mx-2", value = $page,
                  onchange = changePdfPageGen _ =>
                    valueAsNumber[int](qi"page-number-input"))

                tdiv(class = "page-item pointer",
                    onclick = changePdfPageGen (a) => succ a):
                  icon "chevron-right page-link"

              for n in 1..98:
                let p = "http://127.0.0.1:8080/" & align($n, 2, '0') & ".png"
                tdiv(class = "pdf-page card mb-4"):
                  tdiv(class = "card-body"):
                    img(src = p, class = "w-100")
                    h6(class = "card-subtitle mb-2 text-center text-muted"):
                      text fmt"page {n}"

            # for i in 1..20:
              # tdiv(class = "card mb-4"):
              #   tdiv(class = "card-body"):
              #     h4(class = "card-title"):
              #       text "Card title"
              #     h6(class = "card-subtitle mb-2 text-muted"):
              #       text "Card subtitle"
              #     p(class = "card-text"):
              #       text """Some quick example text to build on the card title and make up the bulk of the card's content."""
              #     a(class = "card-link", href = "#"):
              #       text "Card link"
              #     a(class = "card-link", href = "#"):
              #       text "Another link"

          footer(class="mt-2")
