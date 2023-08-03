import std/[with, math, options, lenientops, strformat, random, sets, tables]
import std/[dom, jsconsole, jsffi, jsfetch, asyncjs, sugar]
import karax/[karax, karaxdsl, vdom, vstyles]
import caster, uuid4

import ../[konva, hotkeys, browser]
import ../[ui, canvas, conventions]

# TODO use FontFaceObserver

type
  ColorTheme = tuple
    bg, fg: string

  AppState = enum
    asMessagesView
    asPropertiesView

  FooterState = enum
    fsOverview
    fsColor
    fsFontFamily
    fsFontSize
    fsBorder

  Graph[T] = Table[T, seq[T]]

  AppData = object
    # konva states
    stage: Stage
    shapeLayer: Layer
    transformer: Transformer
    selectedKonvaObject: Option[KonvaObject]
    selectedVisualNode: Option[VisualNode]

    # mouse states
    lastMousePos: Vector
    leftClicked: bool

    # keyboard states
    isCtrlDown: bool
    isSpaceDown: bool

    # app states
    selectedThemeIndex: Natural
    state: AppState
    font: FontConfig
    footerState: FooterState
    sidebarWidth: Natural

    # board data
    edges: Graph[cstring]
    objects: Table[cstring, VisualNode]

  FontConfig = object
    family: string
    size: int
    lineHeight: float # TODO apply
    style: FontStyle

  VisualNode = ref object
    id: cstring
    theme: ColorTheme
    text: cstring
    font: FontConfig
    konvaNode: Group



const
  # TODO: read these from css
  # TODO define maximum map [boarders to not go further if not nessesarry]
  minScale = 0.10 # minimum amount of scale
  maxScale = 10.0
  defaultWidth = 500
  ciriticalWidth = 400
  minimizeWidth = 360

  white: ColorTheme = ("#ffffff", "#889bad")
  smoke: ColorTheme = ("#ecedef", "#778696")
  road: ColorTheme = ("#dfe2e4", "#617288")
  yellow: ColorTheme = ("#fef5a6", "#958505")
  orange: ColorTheme = ("#ffdda9", "#a7690e")
  red: ColorTheme = ("#ffcfc9", "#b26156")
  peach: ColorTheme = ("#fbc4e2", "#af467e")
  pink: ColorTheme = ("#f3d2ff", "#7a5a86")
  purple: ColorTheme = ("#dac4fd", "#7453ab")
  purpleLow: ColorTheme = ("#d0d5fe", "#4e57a3")
  blue: ColorTheme = ("#b6e5ff", "#2d7aa5")
  diomand: ColorTheme = ("#adefe3", "#027b64")
  mint: ColorTheme = ("#c4fad6", "#298849")
  green: ColorTheme = ("#cbfbad", "#479417")
  lemon: ColorTheme = ("#e6f8a0", "#617900")

  colorThemes = [
    white, smoke, road,
    yellow, orange, red,
    peach, pink, purple,
    purpleLow, blue, diomand,
    mint, green, lemon]

  fontFamilies = [
    "Vazirmatn", "cursive", "monospace"]


var app = AppData()
app.sidebarWidth = defaultWidth
app.font.family = "Vazirmatn"
app.font.size = 20


proc applyTheme(txt, box: KonvaObject, theme: ColorTheme) =
  with box:
    fill = theme.bg
    shadowColor = theme.fg
    shadowOffsetY = 6
    shadowBlur = 8
    shadowOpacity = 0.2

  with txt:
    fill = theme.fg

proc applyFont(txt: KonvaObject, font: FontConfig) =
  with txt:
    fontFamily = font.family
    fontSize = font.size

proc setText(v: VisualNode, t: cstring) =
  v.konvaNode.find1("Text").text = t

proc redrawSizeNode(v: KonvaObject, font: FontConfig) =
  let
    node = v.find1 "Rect"
    txt = v.find1 "Text"
    pad = font.size / 2

  with txt:
    applyFont font

  with node:
    x = -pad
    y = -pad
    width = txt.width + pad*2
    height = txt.height + pad*2
    cornerRadius = pad

proc getFocusedFont(): FontConfig =
  if issome app.selectedVisualNode:
    app.selectedVisualNode.get.font
  else:
    app.font

proc setFocusedFontFamily(fn: string) =
  if issome app.selectedVisualNode:
    let v = app.selectedVisualNode.get
    v.font.family = fn
    redrawSizeNode v.konvaNode, v.font
  else:
    app.font.family = fn

proc setFocusedFontSize(s: int) =
  if issome app.selectedVisualNode:
    app.selectedVisualNode.get.font.size = s

    let v = app.selectedVisualNode.get
    v.font.size = s
    redrawSizeNode v.konvaNode, v.font
  else:
    app.font.size = s


proc getFocusedTheme: ColorTheme =
  if issome app.selectedVisualNode:
    app.selectedVisualNode.get.theme
  else:
    colorThemes[app.selectedThemeIndex]

proc setFocusedTheme(themeIndex: int) =
  if issome app.selectedVisualNode:
    let
      c = colorThemes[themeIndex]
      v = app.selectedVisualNode.get
      box = v.konvaNode.find1("Rect")
      txt = v.konvaNode.find1("Text")

    v.theme = c
    applyTheme txt, box, c

  else:
    app.selectedThemeIndex = themeIndex


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

func applyRange[T](value: T, rng: Slice[T]): T =
  min(max(value, rng.a), rng.b)

proc moveStage(v: Vector) =
  app.stage.x = app.stage.x + v.x
  app.stage.y = app.stage.y + v.y

proc changeScale(mouse🖱️: Vector, Δscale: Float) =
  ## zoom in/out with `real` position pinned
  let
    s = ||app.stage.scale
    s′ = applyRange(s + Δscale, minScale .. maxScale)

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
  reset app.selectedKonvaObject
  app.transformer.nodes = []
  app.transformer.remove

proc incl(t: var Transformer, objs: openArray[KonvaShape], layer: Layer) =
  # t.nodes = objs
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

    img.on "click", proc(ke: JsObject as KonvaMouseEvent) {.caster.} =
      stopPropagate ke
      img.draggable = true
      app.selectedKonvaObject = some KonvaObject img
      app.transformer.incl [KonvaShape img], app.shapeLayer

    img.on "transformend", proc(ke: JsObject as KonvaMouseEvent) {.caster.} =
      img.width = img.width * img.scale.x
      img.height = img.height * img.scale.y
      img.scale = v(1, 1)

    app.shapeLayer.add img

proc createNode =
  var
    wrapper = newGroup()
    node = newRect()
    txt = newText()
    vn = VisualNode()

    uid = cstring $uuid4()
    theme = colorThemes[app.selectedThemeIndex]

  with vn:
    font = app.font
    text = "Hello"
    theme = colorThemes[app.selectedThemeIndex]

  with txt:
    x = 0
    y = 0
    align = $hzCenter
    listening = false
    text = vn.text

  with wrapper:
    id = uid
    x = app.lastMousePos.x
    y = app.lastMousePos.y
    add node
    add txt

  redrawSizeNode wrapper, vn.font
  applyTheme txt, node, vn.theme

  node.on "mouseover", proc(ke: JsObject) =
    window.document.body.style.cursor = "pointer"

  node.on "mouseleave", proc(ke: JsObject) =
    window.document.body.style.cursor = ""

  node.on "click", proc(ke: JsObject as KonvaMouseEvent) {.caster.} =
    app.selectedVisualNode = some vn
    redraw()

  vn.konvaNode = wrapper
  app.objects[uid] = vn
  app.shapeLayer.add wrapper

proc mouseDownStage(jo: JsObject as KonvaMouseEvent) {.caster.} =
  app.leftClicked = true

proc mouseMoveStage(ke: JsObject as KonvaMouseEvent) {.caster.} =
  app.lastMousePos = coordinate(v(ke.evt.x, ke.evt.y), app.stage)

proc onStageClick(ke: JsObject as KonvaMouseEvent) {.caster.} =
  stopPropagate ke

proc mouseUpStage(jo: JsObject as KonvaMouseEvent) {.caster.} =
  app.leftClicked = false

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

proc colorSelectBtn(i: int, c: ColorTheme, selectable: bool): Vnode =
  buildHTML:
    tdiv(class = "px-1 h-100 d-flex align-items-center " &
      iff(i == app.selectedThemeIndex, "bg-light")):
      tdiv(class = "color-square mx-2 pointer", style = style(
        (StyleAttr.background, cstring c.bg),
        (StyleAttr.borderColor, cstring c.fg),
      )):
        proc onclick =
          if selectable:
            setFocusedTheme i
            app.footerState = fsOverview

proc fontSizeSelectBtn(size: int, selectable: bool): Vnode =
  buildHTML:
    tdiv(class = "px-1 h-100 d-flex align-items-center " &
      iff(size == app.font.size, "bg-light")):
      tdiv(class = "mx-2 pointer"):
        span:
          text $size

        proc onclick =
          if selectable:
            setFocusedFontSize size
            app.footerState = fsOverview

proc fontFamilySelectBtn(name: string, selectable: bool): Vnode =
  buildHTML:
    tdiv(class = "px-1 h-100 d-flex align-items-center " &
      iff(name == app.font.family, "bg-light")):
      tdiv(class = "mx-2 pointer"):
        span:
          text name

        proc onclick =
          if selectable:
            setFocusedFontFamily name
            app.footerState = fsOverview


proc createDom*(data: RouterData): VNode =
  let freeze = winel.onmousemove != nil
  console.info "just updated the whole virtual DOM"

  # data.hashpart:
  # startsWith "#/": all
  # startsWith "#/completed": completed
  # startsWith "#/active": active

  buildHtml:
    tdiv(class = "karax"):
      main(class = "board-wrapper bg-light overflow-hidden h-100 w-100"):
        konva "board"

      # TODO add zoom in/out buttons

      footer(class = "regions position-absolute bottom-0 left-0 w-100 bg-white border-top border-dark-subtle"):
        tdiv(class = "inside h-100 d-flex align-items-center", style = style(
            StyleAttr.width, cstring $(window.innerWidth - app.sidebarWidth))):

          tdiv(class = "d-inline-flex jusitfy-content-center align-items-center mx-2"):
            if issome app.selectedVisualNode:
              italic(class = "fa-solid fa-crosshairs")
            else:
              italic(class = "fa-solid fa-earth-asia")

          case app.footerState
          of fsOverview:
            let
              font = getFocusedFont()
              theme = getFocusedTheme()

            tdiv(class = "d-inline-flex mx-2 pointer"):
              bold: text "Color: "
              colorSelectBtn(-1, theme, false)

              proc onclick =
                app.footerState = fsColor
                redraw()

            tdiv(class = "d-inline-flex mx-2 pointer"):
              bold: text "Font: "
              span: text font.family

              proc onclick =
                app.footerState = fsFontFamily
                redraw()

            tdiv(class = "d-inline-flex mx-2 pointer"):
              span: text $font.size

              proc onclick =
                app.footerState = fsFontSize
                redraw()

            tdiv(class = "d-inline-flex mx-2 pointer"):
              bold: text "connection: "

            tdiv(class = "d-inline-flex mx-2 pointer"):
              span: text "style "

            tdiv(class = "d-inline-flex mx-2 pointer"):
              span: text "border "

          of fsFontFamily:
            for f in fontFamilies:
              fontFamilySelectBtn(f, true)

          of fsFontSize:
            for s in countup(10, 100, 2):
              fontSizeSelectBtn(s, true)

          of fsColor:
            for i, ct in colorThemes:
              colorSelectBtn(i, ct, true)

          else:
            text "not defined"

      aside(class = "tool-bar btn-group-vertical position-absolute bg-white border border-secondary border-start-0 rounded-right rounded-0"):
        button(class = "btn btn-outline-primary border-0 px-3 py-4"):
          icon "plus fa-lg"

        button(class = "btn btn-outline-primary border-0 px-3 py-4"):
          icon "circle-nodes fa-lg"

        button(class = "btn btn-outline-primary border-0 px-3 py-4"):
          icon "download fa-lg"

        button(class = "btn btn-outline-primary border-0 px-3 py-4"):
          icon "expand fa-lg"

      aside(class = "side-bar position-absolute shadow-sm border bg-white h-100 d-flex flex-row " &
          iff(freeze, "user-select-none ") & iff(app.sidebarWidth <
              ciriticalWidth, "icons-only "),
          style = style(StyleAttr.width, fmt"{app.sidebarWidth}px")):

        tdiv(class = "extender h-100 btn btn-light p-0"):
          proc onMouseDown =
            window.document.body.style.cursor = "e-resize"

            winel.onmousemove = proc(e: Event as MouseEvent) {.caster.} =
              let w = window.innerWidth - e.x
              let w′ =
                if w > minimizeWidth: max(w, minimizeWidth)
                elif w in (minimizeWidth div 2)..minimizeWidth: minimizeWidth
                else: 10

              app.sidebarWidth = w′
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
            case app.state
            of asMessagesView:
              for i in 1..3:
                tdiv(class = "card mb-4"):
                  tdiv(class = "card-body"):
                    tdiv(class = "tw-content"):
                      verbatim msg

            of asPropertiesView:
              let vn = app.selectedVisualNode

              if issome vn:
                let obj = vn.get

                tdiv(class = "form-group"):
                  input(`type` = "string", class = "form-control",
                      placeholder = "text ...", value = obj.text):

                    proc oninput(e: Event, v: Vnode) =
                      let
                        t = obj.konvaNode.getChildren
                        s = e.target.value
                      setText obj, s
                      redrawSizeNode obj.konvaNode, obj.font

          footer(class = "mt-2"):
            discard

document.addEventListener "paste", proc(pasteEvent: Event) =
  discard
  # let file = pasteEvent.clipboardData.files[0]

  # if file && file.type.startsWith("image"):
  #   imageDataUrl(file).then(onPasteOnScreen)
  # else:
  #   console.log("WTF")

when isMainModule:
  echo "compiled at: ", CompileDate, ' ', CompileTime

  # --- UI ---
  setRenderer createDom, "app"

  # --- Canvas ---
  500.setTimeout proc =
    with app:
      stage = newStage "board"
      shapeLayer = newLayer()
      transformer = newTransformer()

    with app.stage:
      width = window.innerWidth
      height = window.innerHeight
      on "click", onStageClick
      on "mousedown pointerdown", mouseDownStage
      on "mousemove pointermove", mouseMoveStage
      on "mouseup pointerup", mouseUpStage
      add app.shapeLayer
    addEventListener app.stage.container, "wheel", onWheel, nonPassive
    addEventListener app.stage.container,
      "contextmenu",
      proc(e: Event) = e.preventDefault


    with app.shapeLayer:
      add tempCircle(0, 0, 8, "black")

    app.stage.on "mousedown", proc(e: JsObject) =
      app.leftClicked = true

    window.document.body.addEventListener "keydown", proc(
        e: Event as KeyboardEvent) {.caster.} =
      if e.key == cstring" ":
        app.isSpaceDown = true
        window.document.body.style.cursor = "move"

    window.document.body.addEventListener "keyup", proc(
        e: Event as KeyboardEvent) {.caster.} =
      if app.isSpaceDown:
        app.isSpaceDown = false
        window.document.body.style.cursor = ""

    app.stage.on "mousemove", proc(e: JsObject as KonvaMouseEvent) {.caster.} =
      if app.leftClicked and app.isSpaceDown:
        moveStage movement e

    app.stage.on "mouseup", proc(e: JsObject) =
      app.leftClicked = false

    moveStage app.stage.center

  addHotkey "delete", proc(ev: Event, h: JsObject) =
    console.log app.selectedKonvaObject
    app.selectedKonvaObject.get.destroy
    app.transformer.nodes = []

  addHotkey "n", proc(ev: Event, h: JsObject) =
    createNode()

  addHotkey "Escape", proc(ev: Event, h: JsObject) =  
    reset app.selectedVisualNode
    redraw()