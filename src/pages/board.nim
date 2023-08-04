import std/[with, math, options, lenientops, strformat, random, sets, tables]
import std/[dom, jsconsole, jsffi, jsfetch, asyncjs, sugar]
import karax/[karax, karaxdsl, vdom, vstyles]
import caster, uuid4

import ../[konva, hotkeys, browser]
import ../[ui, canvas, conventions, graph]

# TODO use FontFaceObserver

type
  ColorTheme = tuple
    bg, fg: string

  SideBarState = enum
    ssMessagesView
    ssPropertiesView

  BoardState = enum
    bsFree
    bsMakeConnection

  FooterState = enum
    fsOverview
    fsColor
    fsFontFamily
    fsFontSize
    fsBorder

  ID = cstring

  AppData = object
    # konva states
    stage: Stage
    hoverGroup: Group
    mainGroup: Group
    bottomGroup: Group
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
    sidebarState: SideBarState
    boardState: BoardState
    font: FontConfig
    footerState: FooterState
    sidebarWidth: Natural

    # board data
    objects: Table[ID, VisualNode]
    edges: Graph[ID]
    edgeInfo: Table[Slice[ID], EdgeInfo]

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
    konva: VisualNodeParts

  VisualNodeParts = object
    wrapper: Group
    box: Rect
    txt: Text

  EdgeInfo = object
    color: ColorTheme
    width: Float
    shape: ConnectionCenterShape

  ConnectionCenterShape = enum
    # directed connection
    ccsTriangle
    ccsDoubleTriangle

    # undirected connection
    ccsCircle
    ccsDiomand
    ccsNothing


const
  # TODO: read these from css
  # TODO define maximum map [boarders to not go further if not nessesarry]
  minScale = 0.10 # minimum amount of scale
  maxScale = 20.0
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


func sorted[T](s: Slice[T]): Slice[T] =
  if s.a < s.b: s
  else: s.b .. s.a


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
  v.text = t
  v.konva.txt.text = t

proc redrawSizeNode(v: VisualNode, font: FontConfig) =
  let pad = font.size / 2

  with v.konva.txt:
    applyFont font

  with v.konva.box:
    x = -pad
    y = -pad
    width = v.konva.txt.width + pad*2
    height = v.konva.txt.height + pad*2
    cornerRadius = pad

# TODO remove implicit global argument `app` and make it explicit

proc getFocusedFont: FontConfig =
  if issome app.selectedVisualNode:
    app.selectedVisualNode.get.font
  else:
    app.font

proc setFocusedFontFamily(fn: string) =
  if issome app.selectedVisualNode:
    let v = app.selectedVisualNode.get
    v.font.family = fn
    redrawSizeNode v, v.font
  else:
    app.font.family = fn

proc setFocusedFontSize(s: int) =
  if issome app.selectedVisualNode:
    app.selectedVisualNode.get.font.size = s

    let v = app.selectedVisualNode.get
    v.font.size = s
    redrawSizeNode v, v.font
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

    v.theme = c
    applyTheme v.konva.txt, v.konva.box, c

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
      app.transformer.incl [KonvaShape img], app.mainGroup.getLayer

    img.on "transformend", proc(ke: JsObject as KonvaMouseEvent) {.caster.} =
      img.width = img.width * img.scale.x
      img.height = img.height * img.scale.y
      img.scale = v(1, 1)

    app.mainGroup.add img

proc createNode =
  var
    wrapper = newGroup()
    box = newRect()
    txt = newText()
    vn = VisualNode()

    uid = cstring $uuid4()
    theme = colorThemes[app.selectedThemeIndex]

  with vn:
    id = uid
    font = app.font
    text = "Hello"
    theme = colorThemes[app.selectedThemeIndex]

  with vn.konva:
    wrapper = wrapper
    box = box
    txt = txt

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
    add box
    add txt
    draggable = true

  redrawSizeNode vn, vn.font
  applyTheme txt, box, vn.theme

  box.on "mouseover", proc =
    window.document.body.style.cursor = "pointer"

  box.on "mouseleave", proc =
    window.document.body.style.cursor = ""

  box.on "click", proc =
    let sv = app.selectedVisualNode

    case app.boardState
    of bsFree:
      if issome sv:
        if sv.get == vn:
          sv.get.konva.wrapper.opacity = 0.5
          app.boardState = bsMakeConnection
        else:
          app.selectedVisualNode = some vn
      else:
        app.selectedVisualNode = some vn


    of bsMakeConnection:
      if sv.get == vn:
        discard
      else:
        app.selectedVisualNode = some vn

        let
          b1 = box
          b2 = sv.get.konva.box
          w2 = sv.get.konva.wrapper
          v1 = wrapper.position + v(b1.width, b1.height) / 2
          v2 = w2.position + v(b2.width, b2.height) / 2
          id1 = uid
          id2 = sv.get.id
          conn = sorted id1..id2
          path = @[v1, v2]

        var
          line = newLine()
          ei = EdgeInfo()

        with line:
          strokeWidth = 2
          stroke = getFocusedTheme().fg
          points = path

        app.bottomGroup.add line
        console.log line
        console.log line.points
        console.log path
        
        app.edges.addConn conn
        app.edgeInfo[conn] = ei
        app.boardState = bsFree
        w2.opacity = 1

    redraw()

  wrapper.on "dragstart", proc =
    window.document.body.style.cursor = "move"

  wrapper.on "dragend", proc =
    window.document.body.style.cursor = "pointer"


  app.objects[uid] = vn
  app.mainGroup.getLayer.add wrapper
  app.selectedVisualNode = some vn
  redraw()

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

proc changeStateGen*(to: SidebarState): proc =
  proc =
    app.sidebarState = to

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
      tdiv(class = "color-square mx-1 pointer", style = style(
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
              bold(class = "me-2"): text "Font: "
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
              span(class = "mx-1"):
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
              tdiv(class = "nav-item", onclick = changeStateGen ssMessagesView):
                span(class = "nav-link px-3 pointer" &
                    iff(app.sidebarState == ssMessagesView, " active")):
                  span(class = "caption"):
                    text "Messages "
                  icon "message"

              tdiv(class = "nav-item", onclick = changeStateGen ssPropertiesView):
                span(class = "nav-link px-3 pointer" &
                  iff(app.sidebarState == ssPropertiesView, " active")):
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
            case app.sidebarState
            of ssMessagesView:
              for i in 1..3:
                tdiv(class = "card mb-4"):
                  tdiv(class = "card-body"):
                    tdiv(class = "tw-content"):
                      verbatim msg

            of ssPropertiesView:
              let vn = app.selectedVisualNode

              if issome vn:
                let obj = vn.get

                tdiv(class = "form-group"):
                  input(`type` = "string", class = "form-control",
                      placeholder = "text ...", value = obj.text):

                    proc oninput(e: Event, v: Vnode) =
                      let s = e.target.value
                      setText obj, s
                      redrawSizeNode obj, obj.font

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
    let layer = newLayer()

    with app:
      stage = newStage "board"
      transformer = newTransformer()
      hoverGroup = newGroup()
      mainGroup = newGroup()
      bottomGroup = newGroup()

    with app.stage:
      width = window.innerWidth
      height = window.innerHeight
      on "click", onStageClick
      on "mousedown pointerdown", mouseDownStage
      on "mousemove pointermove", mouseMoveStage
      on "mouseup pointerup", mouseUpStage
      add layer

    addEventListener app.stage.container, "wheel", onWheel, nonPassive
    addEventListener app.stage.container, "contextmenu", proc(e: Event) =
      e.preventDefault

    with layer:
      add tempCircle(0, 0, 8, "black")
      add app.bottomGroup
      add app.mainGroup
      add app.hoverGroup

    with app.stage:
      add layer

      on "mousedown", proc =
        app.leftClicked = true

      on "mousemove", proc(e: JsObject as KonvaMouseEvent) {.caster.} =
        if app.leftClicked and app.isSpaceDown:
          moveStage movement e

      on "mouseup", proc =
        app.leftClicked = false

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

    moveStage app.stage.center

  addHotkey "delete", proc =
    console.log app.selectedKonvaObject
    app.selectedKonvaObject.get.destroy
    app.transformer.nodes = []

  addHotkey "Escape", proc =
    reset app.selectedVisualNode
    redraw()

  addHotkey "n", createNode

  # TODO move
  addHotkey "m", proc = discard

  # TODO make connection
  addHotkey "c", proc = discard

  # TODO show/hide side bar
  addHotkey "b", proc = discard
