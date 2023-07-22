import std/[with, math, options, lenientops, strformat]
from std/jsffi import JsObject
import std/[dom, jsconsole, jsffi, jsfetch, asyncjs, sugar]
import karax/[karax, karaxdsl, vdom, vstyles]
import caster

import konva, hotkeys, browser
import ui, canvas, conventions

# TODO FontFaceObserver

type
  AppState = enum
    asMessagesView
    asPropertiesView

  AppData = object
    stage: Stage
    layer: Layer
    # TODO add background layer
    transformer: Transformer
    selectedObject: Option[KonvaObject]
    lastMousePos: Vector
    isMouseDown: bool

    state: AppState
    sidebarWidth: Natural

# TODO: read these from css
const
  defaultWidth = 500
  ciriticalWidth = 400
  minimizeWidth = 260

# TODO define maximum map [boarders to not go further if not nessesarry]
const ⌊scale⌋ = 0.01 # minimum amount of scale
var app: AppData
app.sidebarWidth = defaultWidth

# --- helpers ---

func coordinate(mouse: Vector, scale, offsetx, offsety: Float): Vector =
  v(
    (-offsetx + mouse.x) / scale,
    (-offsety + mouse.y) / scale)

proc coordinate(pos: Vector, stage: Stage): Vector =
  coordinate pos, ||stage.scale, stage.x, stage.y


func center(scale, offsetx, offsety, width, height: Float): Vector =
  ## real coordinate of center of the canvas
  v((width/2 - offsetx) / scale,
    (height/2 - offsety) / scale)

proc center(stage: Stage): Vector =
  ## real coordinate of center of the canvas
  center(
    ||app.stage.scale,
    app.stage.x, app.stage.y,
    app.stage.width, app.stage.height)

# --- actions ---

proc moveStage(v: Vector) =
  app.stage.x = app.stage.x + v.x
  app.stage.y = app.stage.y + v.y

proc changeScale(mouse🖱️: Vector, Δscale: Float) =
  ## zoom in/out with `real` position pinned
  let
    s = ||app.stage.scale
    s′ = max(s + Δscale, ⌊scale⌋)

    w = app.stage.width
    h = app.stage.height

    real = coordinate(mouse🖱️, app.stage)
    realϟ = real * s′

  app.stage.scale = s′
  app.stage.x = -realϟ.x + w/2
  app.stage.y = -realϟ.y + h/2

  let
    real′ = coordinate(mouse🖱️, app.stage)
    d = real′ - real

  moveStage d * s′

proc resetSelected =
  reset app.selectedObject
  app.transformer.nodes = []
  app.transformer.remove

proc incl(t: var Transformer, objs: openArray[KonvaShape], layer: Layer) =
  t.nodes = objs
  layer.add t
  layer.batchDraw

# --- events ---

# TODO remove exportc and make all of the codes written in Nim

proc onPasteOnScreen(data: cstring) {.exportc.} =
  newImageFromUrl data, proc(img: Image) =
    with img:
      x = app.lastMousePos.x
      y = app.lastMousePos.y
      strokeWidth = 2
      stroke = "black"
      # setAttr

    # img.on "click", proc(ke: JsObject as KonvaClickEvent) {.caster.} =
    #   stopPropagate ke
    #   img.draggable = true
    #   app.selectedObject = some KonvaObject img
    #   app.transformer.incl [KonvaShape img], app.layer

    # img.on "transformend", proc(ke: JsObject as KonvaClickEvent) {.caster.} =
    #   img.width = img.width * img.scale.x
    #   img.height = img.height * img.scale.y
    #   img.scale = v(1, 1)

    app.layer.add img

proc createNode() =
  var
    node = newRect()
    txt = newText()

  with txt:
    x = app.lastMousePos.x
    y = app.lastMousePos.y
    fontFamily = "Vazirmatn"
    fill = "rgb(169, 108, 17)"
    fontSize = 20
    align = $hzCenter
    text = "سلام دوستانس\nچطورید؟"
    listening = false

  with node:
    x = app.lastMousePos.x
    y = app.lastMousePos.y
    width = txt.getClientRect.width
    height = txt.getClientRect.height
    strokeWidth = 2
    fill = "#ffdda9"
    cornerRadius = 10


  node.on "mouseover", proc(ke: JsObject) =
    window.document.body.style.cursor = "pointer"

  node.on "mouseleave", proc(ke: JsObject) =
    window.document.body.style.cursor = ""

  node.on "click", proc(ke: JsObject) =
    app.state = asMessagesView
    console.log ke
    node.fill = "red"
    txt.fill = "white"
    redraw()

  console.log node

  app.layer.add node
  app.layer.add txt

proc mouseDownStage(jo: JsObject as KonvaClickEvent) {.caster.} =
  app.isMouseDown = true

proc mouseMoveStage(ke: JsObject as KonvaClickEvent) {.caster.} =
  app.lastMousePos = coordinate(v(ke.evt.x, ke.evt.y), app.stage)

proc onStageClick(ke: JsObject as KonvaClickEvent) {.caster.} =
  if issome app.selectedObject:
    app.selectedObject.get.draggable = false
    resetSelected()

  stopPropagate ke

proc mouseUpStage(jo: JsObject as KonvaClickEvent) {.caster.} =
  app.isMouseDown = false

proc onWheel(e: Event as WheelEvent) {.caster.} =
  preventDefault e

  let mp = v(e.x, e.y)
  app.lastMousePos = coordinate(mp, app.stage)

  if e.ctrlKey: # pinch-zoom
    let
      s = ||app.stage.scale
      ⋊s = exp(-e.Δy / 100)

    changeScale mp, s*(⋊s - 1)

  else: # panning
    moveStage v(e.Δx, e.Δy) * -1



proc isMaximized*: bool =
  app.sidebarWidth >= window.innerWidth * 2/3

proc maximize* =
  app.sidebarWidth =
    if isMaximized(): defaultWidth
    else: window.innerWidth
  redraw()

proc changeStateGen*(to: AppState): proc =
  proc =
    app.state = to

var msg = cstring"loading ..."

template set(vari, data): untyped =
  vari = data


proc getMsg() {.async.} =
  await:
    fetch(cstring"/pages/2.html")
    .then((response: Response) => response.text)
    .then((s: cstring) => set(msg, s))
    .catch((err: Error) => console.log("Request Failed", err))

  redraw()

discard getMsg()

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
          iff(freeze, "user-select-none ") & iff(app.sidebarWidth <
              ciriticalWidth, "icons-only "),
          style = style(StyleAttr.width, fmt"{app.sidebarWidth}px")):

        tdiv(class = "extender h-100 btn btn-light p-0"):
          proc onMouseDown =
            window.document.body.style.cursor = "e-resize"

            winel.onmousemove = proc(e: Event as MouseEvent) {.caster.} =
              app.sidebarWidth = max(window.innerWidth - e.x, minimizeWidth)
              redraw()

            winel.onmouseup = proc(e: Event) =
              window.document.body.style.cursor = ""
              reset winel.onmousemove
              reset winel.onmouseup

        tdiv(class = "d-flex flex-column w-100"):
          header(class = "nav nav-tabs d-flex flex-row justify-content-between align-items-end bg-light mb-2"):

            tdiv(class = "d-flex flex-row"):
              tdiv(class = "nav-item", onclick = changeStateGen asMessagesView):
                span(class = "nav-link px-3 pointer" &
                    iff(app.state == asMessagesView, " active")):
                  span(class = "caption"):
                    text "Messages "
                  icon "message"

              tdiv(class = "nav-item", onclick = changeStateGen asPropertiesView):
                span(class = "nav-link px-3 pointer" &
                  iff(app.state == asPropertiesView, " active")):
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
            if app.state == asMessagesView:
              for i in 1..3:
                tdiv(class = "card mb-4"):
                  tdiv(class = "card-body"):
                    tdiv(class = "tw-content"):
                      verbatim msg

          footer(class = "mt-2"):
            discard


when isMainModule:
  echo "compiled at: ", CompileDate, ' ', CompileTime

  # --- UI ---
  setRenderer createDom, "app"

  # --- Canvas ---
  500.setTimeout proc =
    with app:
      stage = newStage "board"
      layer = newLayer()
      transformer = newTransformer()

    with app.stage:
      width = window.innerWidth
      height = window.innerHeight
      on "click", onStageClick
      on "mousedown pointerdown", mouseDownStage
      on "mousemove pointermove", mouseMoveStage
      on "mouseup pointerup", mouseUpStage
      add app.layer
    addEventListener app.stage.container, "wheel", onWheel, nonPassive
    addEventListener app.stage.container, "contextmenu", proc(
        e: Event) = e.preventDefault

    with app.layer:
      add tempCircle(0, 0, 8, "black")

    moveStage app.stage.center

  addHotkey "delete", proc(ev: Event, h: JsObject) =
    app.selectedObject.get.destroy
    app.transformer.nodes = []

  addHotkey "n", proc(ev: Event, h: JsObject) =
    createNode()
