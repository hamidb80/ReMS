import std/[strformat, strutils, sugar, lenientops]
import std/[dom, jsconsole]
import karax/[karaxdsl, vdom, vstyles, karax], caster
import conventions, browser


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
    MessagesView
    PropertiesView

# TODO: read these from css
const
  defaultWidth = 500
  ciriticalWidth = 400
  minimizeWidth = 260

var
  sidebarWidth = defaultWidth
  state = PropertiesView


proc changeStateGen(to: State): proc =
  proc =
    state = to

proc isMaximized: bool =
  sidebarWidth >= window.innerWidth * 2/3

proc maximize =
  sidebarWidth =
    if isMaximized(): defaultWidth
    else: window.innerWidth
  redraw()


proc createDom*(data: RouterData): VNode =
  let freeze = winel.onmousemove != nil
  console.info "just updated the whole virtual DOM"

  # data.hashpart:
  # startsWith "#/": all
  # startsWith "#/completed": completed
  # startsWith "#/active": active

  buildHtml:
    tdiv(class = "karax"):
      main(class = "board-wrapper overflow-hidden h-100 w-100"):
        konva "board"

      footer(class = "regions position-absolute bottom-0 left-0 w-100 bg-light border-top border-secondary"):
        discard

      aside(class = "tool-bar btn-group-vertical position-absolute bg-light border border-secondary border-start-0 rounded-right rounded-0"):
        button(class = "btn btn-outline-primary border-0 px-3 py-4"):
          icon "plus fa-lg"

        button(class = "btn btn-outline-primary border-0 px-3 py-4"):
          icon "download fa-lg"

        button(class = "btn btn-outline-primary border-0 px-3 py-4"):
          icon "crop-simple fa-lg"

        button(class = "btn btn-outline-primary border-0 px-3 py-4"):
          icon "expand fa-lg"

        button(class = "btn btn-outline-primary border-0 px-3 py-4"):
          icon "vector-square fa-lg"


      aside(class = "side-bar position-absolute shadow-sm border bg-white h-100 d-flex flex-row " &
          iff(freeze, "user-select-none ") & iff(sidebarWidth < ciriticalWidth,
              "icons-only "),
          style = style(StyleAttr.width, fmt"{sidebarWidth}px")):

        tdiv(class = "extender h-100 btn btn-light p-0"):
          proc onMouseDown =
            window.document.body.style.cursor = "e-resize"

            winel.onmousemove = proc(e: Event as MouseEvent) {.caster.} =
              sidebarWidth = max(window.innerWidth - e.x, minimizeWidth)
              redraw()

            winel.onmouseup = proc(e: Event) =
              window.document.body.style.cursor = ""
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
            discard

          footer(class = "mt-2"):
            discard
