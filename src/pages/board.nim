import std/[with, math, options, lenientops, strformat, random, sets, tables]
import std/[dom, jsconsole, jsffi, jsfetch, asyncjs, sugar]
import karax/[karax, karaxdsl, vdom, vstyles]
import caster, uuid4, questionable, prettyvec

import ../[konva, hotkeys, browser]
import ../[ui, conventions, graph]

# TODO use FontFaceObserver

type
  ColorTheme = tuple
    bg, fg, st: string

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
    fsBorderWidth
    fsBorderShape

  ID = cstring

  Region = range[1..4]

  Axis = enum
    aVertical
    aHorizontal

  Degree = distinct float
  Radian = distinct float

  AppData = object
    # konva states
    stage: Stage
    hoverGroup: Group
    mainGroup: Group
    bottomGroup: Group

    tempEdge: Edge
    transformer: Transformer
    # selectedKonvaObject: Option[KonvaObject]

    # app states
    hoverVisualNode: Option[VisualNode]
    selectedVisualNode: Option[VisualNode]
    selectedEdge: Option[Edge]

    font: FontConfig
    edge: EdgeConfig

    sidebarState: SideBarState
    boardState: BoardState
    footerState: FooterState

    theme: ColorTheme
    sidebarWidth: Natural

    lastMousePos: Vector
    leftClicked: bool

    isCtrlDown: bool
    isSpaceDown: bool

    # board data
    objects: Table[ID, VisualNode]
    edges: Graph[ID]
    edgeInfo: Table[Slice[ID], Edge]

  FontConfig = object
    family: string
    size: int
    style: FontStyle
    # lineHeight: Float

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

  Tenth = distinct int

  Edge = ref object
    config: EdgeConfig
    konva: EdgeKonvaNodes

  EdgeKonvaNodes = object
    wrapper: Group
    shape: KonvaShape
    line: Line

  EdgeConfig = object
    theme: ColorTheme
    width: Tenth
    centerShape: ConnectionCenterShapeKind # TODO

  ConnectionCenterShapeKind = enum
    # undirected connection
    ccsNothing
    ccsCircle
    ccsDiomand
    ccsSquare
    # directed connection
    ccsTriangle
    ccsDoubleTriangle

  CssCursor = enum
    ccNone = ""
    ccMove = "move"
    ccPointer = "pointer"
    ccResizex = "e-resize"
    # ccAdd


const
  # TODO: read these from css
  # TODO define maximum map [boarders to not go further if not nessesarry]
  minScale = 0.10 # minimum amount of scale
  maxScale = 20.0
  defaultWidth = 500
  ciriticalWidth = 400
  minimizeWidth = 360

  invalidTheme: ColorTheme = ("", "", "")
  white: ColorTheme = ("#ffffff", "#889bad", "#a5b7cf")
  smoke: ColorTheme = ("#ecedef", "#778696", "#9eaabb")
  road: ColorTheme = ("#dfe2e4", "#617288", "#808fa6")
  yellow: ColorTheme = ("#fef5a6", "#958505", "#dec908")
  orange: ColorTheme = ("#ffdda9", "#a7690e", "#e99619")
  red: ColorTheme = ("#ffcfc9", "#b26156", "#ff634e")
  peach: ColorTheme = ("#fbc4e2", "#af467e", "#e43e97")
  pink: ColorTheme = ("#f3d2ff", "#7a5a86", "#c86fe9")
  purple: ColorTheme = ("#dac4fd", "#7453ab", "#a46bff")
  purpleLow: ColorTheme = ("#d0d5fe", "#4e57a3", "#7886f4")
  blue: ColorTheme = ("#b6e5ff", "#2d7aa5", "#399bd3")
  diomand: ColorTheme = ("#adefe3", "#027b64", "#00d2ad")
  mint: ColorTheme = ("#c4fad6", "#298849", "#25ba58")
  green: ColorTheme = ("#cbfbad", "#479417", "#52d500")
  lemon: ColorTheme = ("#e6f8a0", "#617900", "#a5cc08")

  colorThemes = [
    white, smoke, road,
    yellow, orange, red,
    peach, pink, purple,
    purpleLow, blue, diomand,
    mint, green, lemon]

  fontFamilies = [
    "Vazirmatn", "cursive", "monospace"]

# TODO easier control when creating connection
# TODO add hover view when selecting a node
var app = AppData()


# ----- Util

func sorted[T](s: Slice[T]): Slice[T] =
  if s.a < s.b: s
  else: s.b .. s.a

template `?`(a): untyped =
  issome a

template `.!`(a, b): untyped =
  a.get.b

# ----- Degree

func `<`(a, b: Degree): bool {.borrow.}
func `==`(a, b: Degree): bool {.borrow.}
func `<=`(a, b: Degree): bool {.borrow.}
func `-`(a, b: Degree): Degree {.borrow.}
func `+`(a, b: Degree): Degree {.borrow.}
func `$`(a: Degree): string {.borrow.}

func degToRad(d: Degree): Radian =
  Radian degToRad d.float

func tan(d: Degree): float =
  tan float degToRad d

func cot(d: Degree): float =
  cot float degToRad d

func `-`(d: Degree): Degree =
  Degree 360 - d.float

# ----- Tenth

func `==`(a, b: Tenth): bool {.borrow.}

func `$`(t: Tenth): string =
  let
    n = t.int
    a = n div 10
    b = n mod 10

  $a & '.' & $b

func toFloat(t: Tenth): Float =
  t.int / 10

func toTenth(f: Float): Tenth =
  let n = toint f * 10
  Tenth n


proc applyTheme(txt, box: KonvaObject, theme: ColorTheme) =
  with box:
    fill = theme.bg
    shadowColor = theme.st
    shadowOffsetY = 6
    shadowBlur = 8
    shadowOpacity = 0.2

  with txt:
    fill = theme.fg

proc applyFont(txt: KonvaObject, font: FontConfig) =
  with txt:
    fontFamily = font.family
    fontSize = font.size

func center(vn: VisualNode): Vector =
  let
    w = vn.konva.wrapper
    b = vn.konva.box
  
  w.position + b.position + b.size.v / 2

func area(vn: VisualNode): Area =
  let
    w = vn.konva.wrapper
    b = vn.konva.box

  b.area + w.position

proc redrawSizeNode(v: VisualNode, font: FontConfig) =
  # TODO keep center
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
  if v =? app.selectedVisualNode:
    v.font
  else:
    app.font

proc setCursor(c: CssCursor) =
  window.document.body.style.cursor = $c

proc setFocusedFontFamily(fn: string) =
  if issome app.selectedVisualNode:
    let v = app.selectedVisualNode.get
    v.font.family = fn
    redrawSizeNode v, v.font
  else:
    app.font.family = fn

proc hover(vn: VisualNode) =
  app.hoverVisualNode = some vn

proc unhover(vn: VisualNode) =
  reset app.hoverVisualNode

proc highlight(vn: VisualNode) =
  vn.konva.wrapper.opacity = 0.5

proc removeHighlight(vn: VisualNode) =
  vn.konva.wrapper.opacity = 1

proc unselect =
  if v =? app.selectedVisualNode:
    removeHighlight v
    reset app.selectedVisualNode

  if e =? app.selectedEdge:
    reset app.selectedEdge

proc select(vn: VisualNode) =
  unselect()
  app.selectedVisualNode = some vn

proc select(e: Edge) =
  unselect()
  app.selectedEdge = some e


func onBorder(axis: Axis, limit: Float, θ: Degree): Vector =
  case axis
  of aVertical:
    let
      m = tan θ
      y = m * limit

    v(limit, -y)

  of aHorizontal:
    let
      m⁻¹ = cot θ
      x = m⁻¹ * limit

    v(-x, limit)

func onBorder(dd: (Axis, Float), θ: Degree): Vector =
  onBorder dd[0], dd[1], θ

func aaa(a: Area, r: Region): tuple[axis: Axis, limit: Float] =
  case r
  of 1: (aVertical, a.x2)
  of 3: (aVertical, a.x1)
  of 2: (aHorizontal, a.y1)
  of 4: (aHorizontal, a.y2)

func normalize(θ: Degree): Degree =
  let
    d = θ.float
    (i, f) = splitDecimal d
    i′ = (i mod 360)

  if d >= 0: Degree i′ + f
  else: Degree 360 + i′ + f

func arctan(v: Vector): Degree =
  normalize arctan2(-v.y, v.x).radToDeg.Degree

func whichRegion(θ: Degree, a: Area): Region =
  ## devides the rectangle into 4 regions according to its diameters
  let
    d = a.topRight - a.center
    λ = normalize arctan d
  assert θ >= Degree 0.0
  assert λ >= Degree 0.0

  if θ <= λ: 1
  elif θ <= Degree(180.0) - λ: 2
  elif θ <= Degree(180.0) + λ: 3
  elif θ <= Degree(360.0) - λ: 4
  else: 1

proc updateEdge(e: Edge, a1: Area, c1: Vector, a2: Area, c2: Vector) =
  let
    d = c2 - c1
    θ = arctan d
    r1 = whichRegion(θ, a1)
    r2 = whichRegion(θ, a2)
    h =
      if c2 in a1: c1
      else: c1 + onBorder(aaa(a1 + -c1, r1), θ)
    t =
      if c2 in a1: c1
      else: c2 - onBorder(aaa(a2 + -c2, r2), θ)

  e.konva.line.points = [c1, c2]
  e.konva.shape.position = (h + t) / 2

proc updateEdgeWidth(e: Edge, w: Tenth) =
  let v = toFloat w
  e.config.width = w
  e.konva.line.strokeWidth = v
  with e.konva.shape:
    strokeWidth = v
    radius = v * 5

proc updateEdgeTheme(e: Edge, t: ColorTheme) =
  e.config.theme = t
  e.konva.line.stroke = t.st
  with e.konva.shape:
    stroke = t.st
    fill = t.bg

proc newEdge(c: EdgeConfig): Edge =
  let k = EdgeKonvaNodes(
    wrapper: newGroup(),
    shape: newCircle(),
    line: newLine())

  with k.line:
    listening = false

  with k.shape:
    on "mouseenter", proc =
      setCursor ccPointer

    on "mouseleave", proc =
      setCursor ccNone

    on "click", proc =
      echo "Hey!"

  with k.wrapper:
    add k.line
    add k.shape

  Edge(config: c, konva: k)

proc cloneEdge(e: Edge): Edge =
  result = Edge(
    config: e.config,
    konva: EdgeKonvaNodes(
      line: Line clone e.konva.line,
      shape: KonvaShape clone e.konva.shape,
      wrapper: newGroup()))

  with result.konva.wrapper:
    add result.konva.line
    add result.konva.shape

  with result.konva.shape:
    off "click"
    on "click", proc =
      unselect()
      app.selectedEdge = some result
      redraw()

proc redrawConnectionsTo(uid: Id) =
  for id in app.edges[uid]:
    let
      ei = app.edgeInfo[sorted id..uid]
      ps = ei.konva.line.points.foldPoints
      n1 = app.objects[id]
      n2 = app.objects[uid]

    updateEdge ei, n1.area, n1.center, n2.area, n2.center

# TODO keep the center of node when changing size or text or ...
proc setText(v: VisualNode, t: cstring) =
  v.text = t
  v.konva.txt.text = t
  redrawSizeNode v, v.font
  redrawConnectionsTo v.id

proc setFocusedFontSize(s: int) =
  if v =? app.selectedVisualNode:
    v.font.size = s
    redrawSizeNode v, v.font
    redrawConnectionsTo v.id
  else:
    app.font.size = s

proc setFocusedEdgeWidth(w: Tenth) =
  if e =? app.selectedEdge:
    updateEdgeWidth e, w
  else:
    app.edge.width = w

proc getFocusedEdgeWidth: Tenth =
  if e =? app.selectedEdge:
    e.config.width
  else:
    app.edge.width

proc getFocusedTheme: ColorTheme =
  if v =? app.selectedVisualNode: v.theme
  elif e =? app.selectedEdge: e.config.theme
  else: app.theme

proc setFocusedTheme(theme: ColorTheme) =
  if v =? app.selectedVisualNode:
    v.theme = theme
    applyTheme v.konva.txt, v.konva.box, theme
  elif e =? app.selectedEdge:
    updateEdgeTheme e, theme
  else:
    app.theme = theme

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

func limit[T](value: T, rng: Slice[T]): T =
  min(max(value, rng.a), rng.b)

proc moveStage(v: Vector) =
  app.stage.x = app.stage.x + v.x
  app.stage.y = app.stage.y + v.y

proc changeScale(mouse🖱️: Vector, Δscale: Float) =
  ## zoom in/out with `real` position pinned
  let
    s = ||app.stage.scale
    s′ = limit(s + Δscale, minScale .. maxScale)

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
  discard
  # reset app.selectedKonvaObject
  # app.transformer.nodes = []
  # app.transformer.remove

proc incl(t: var Transformer, objs: openArray[KonvaShape], layer: Layer) =
  # t.nodes = objs
  layer.add t
  layer.batchDraw


# --- events ---

proc createNode =
  var
    wrapper = newGroup()
    box = newRect()
    txt = newText()
    vn = VisualNode()
    uid = cstring $uuid4()

  with vn:
    id = uid
    font = app.font
    text = "Hello"
    theme = app.theme

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

  with box:
    on "mouseover", proc =
      hover vn
      setCursor ccPointer

    on "mouseleave", proc =
      unhover vn
      setCursor ccNone

    on "click", proc =
      case app.boardState
      of bsFree:
        if sv =? app.selectedVisualNode:
          if sv == vn:
            let w = vn.konva.wrapper
            # TODO make a function
            highlight sv
            show app.tempEdge.konva.wrapper
            updateEdge app.tempEdge, w.area, w.center, w.area, w.center
            updateEdgeTheme app.tempEdge, getFocusedTheme()
            updateEdgeWidth app.tempEdge, getFocusedEdgeWidth()
            app.boardState = bsMakeConnection
          else:
            select vn
        else:
          select vn

      of bsMakeConnection:
        let sv = !app.selectedVisualNode
        if sv == vn:
          discard
        else:
          let
            id1 = uid
            id2 = sv.id
            conn = sorted id1..id2

          var ei = cloneEdge app.tempEdge

          if conn notin app.edgeInfo:
            app.bottomGroup.add ei.konva.wrapper
            app.edges.addConn conn
            app.edgeInfo[conn] = ei
            app.boardState = bsFree
            hide app.tempEdge.konva.wrapper
            removeHighlight sv

      redraw()

  with wrapper:
    x = app.lastMousePos.x
    y = app.lastMousePos.y
    id = uid
    add box
    add txt
    draggable = true

    on "dragstart", proc =
      setCursor ccMove

    on "dragend", proc =
      setCursor ccPointer

    on "dragmove", proc =
      redrawConnectionsTo uid

  redrawSizeNode vn, vn.font
  applyTheme txt, box, vn.theme

  app.objects[uid] = vn
  app.mainGroup.getLayer.add wrapper
  select vn
  redraw()

proc mouseDownStage(jo: JsObject as KonvaMouseEvent) {.caster.} =
  app.leftClicked = true

proc newPoint(pos: Vector): Circle =
  result = newCircle()
  with result:
    radius = 1
    position = pos

proc mouseMoveStage(ke: JsObject as KonvaMouseEvent) {.caster.} =
  app.lastMousePos = coordinate(v(ke.evt.x, ke.evt.y), app.stage)

  if app.boardState == bsMakeConnection:
    let
      v = app.hoverVisualNode
      n1 = !app.selectedVisualNode

    if ?v:
      let n2 = !v
      updateEdge app.tempEdge, n1.area, n1.center, n2.area, n2.center
    else: 
      let t = newPoint app.lastMousePos
      updateEdge app.tempEdge, n1.area, n1.center, t.area, t.position


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

template set(vari, data): untyped =
  vari = data


# discard getMsg()
var msg = cstring"loading ..."
proc getMsg() {.async.} =
  await:
    fetch(cstring"/pages/2.html")
    .then((response: Response) => response.text)
    .then((s: cstring) => set(msg, s))
    .catch((err: Error) => console.log("Request Failed", err))

  redraw()

proc colorSelectBtn(selectedTheme, theme: ColorTheme, selectable: bool): Vnode =
  buildHTML:
    tdiv(class = "px-1 h-100 d-flex align-items-center " &
      iff(selectedTheme == theme, "bg-light")):
      tdiv(class = "color-square mx-1 pointer", style = style(
        (StyleAttr.background, cstring theme.bg),
        (StyleAttr.borderColor, cstring theme.fg),
      )):
        proc onclick =
          if selectable:
            setFocusedTheme theme
            app.footerState = fsOverview

proc fontSizeSelectBtn[T](size, selected: T, selectable: bool, fn: proc()): Vnode =
  buildHTML:
    tdiv(class = "px-1 h-100 d-flex align-items-center " &
      iff(size == selected, "bg-light")):
      tdiv(class = "mx-2 pointer"):
        span:
          text $size

        proc onclick =
          if selectable:
            fn()

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
            if ?app.selectedVisualNode:
              italic(class = "fa-solid fa-crosshairs")
            elif ?app.selectedEdge:
              italic(class = "fa-solid fa-grip-lines")
            else:
              italic(class = "fa-solid fa-earth-asia")

          case app.footerState
          of fsOverview:
            let
              font = getFocusedFont()
              theme = getFocusedTheme()

            tdiv(class = "d-inline-flex mx-2 pointer"):
              bold: text "Color: "
              colorSelectBtn(invalidTheme, theme, false)

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
              span: text "shape "

              proc onclick =
                app.footerState = fsBorderShape

            tdiv(class = "d-inline-flex mx-2 pointer"):
              span(class = "me-2"): text "width: "
              span: text $getFocusedEdgeWidth()

              proc onclick =
                app.footerState = fsBorderWidth

          of fsFontFamily:
            for f in fontFamilies:
              fontFamilySelectBtn(f, true)

          of fsFontSize:
            for s in countup(10, 200, 10):
              fontSizeSelectBtn s, getFocusedFont().size, true, capture(s, proc =
                setFocusedFontSize s
                app.footerState = fsOverview)

          of fsBorderWidth:
            for w in countup(10, 100, 5):
              fontSizeSelectBtn w.Tenth, app.edge.width, true, capture(w, proc =
                setFocusedEdgeWidth w.Tenth
                app.footerState = fsOverview)

          of fsColor:
            for i, ct in colorThemes:
              span(class = "mx-1"):
                colorSelectBtn(invalidTheme, ct, true)

          else:
            text "not defined"

      aside(class = "tool-bar btn-group-vertical position-absolute bg-white border border-secondary border-start-0 rounded-right rounded-0"):
        button(class = "btn btn-outline-primary border-0 px-3 py-4"):
          icon "plus fa-lg"

        button(class = "btn btn-outline-primary border-0 px-3 py-4"):
          # TODO show shortcut and name via a tooltip
          icon "expand fa-lg"

        button(class = "btn btn-outline-primary border-0 px-3 py-4"):
          icon "download fa-lg"

      aside(class = "side-bar position-absolute shadow-sm border bg-white h-100 d-flex flex-row " &
          iff(freeze, "user-select-none ") & iff(app.sidebarWidth <
              ciriticalWidth, "icons-only "),
          style = style(StyleAttr.width, fmt"{app.sidebarWidth}px")):

        tdiv(class = "extender h-100 btn btn-light p-0"):
          proc onMouseDown =
            setCursor ccresizex

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

          footer(class = "mt-2"):
            discard

when isMainModule:
  echo "compiled at: ", CompileDate, ' ', CompileTime

  setRenderer createDom, "app"

  setTimeout 500, proc =
    let 
      layer = newLayer()
      centerCircle = newCircle()

    with centerCircle:
      x = 0
      y = 0
      radius = 2
      stroke = "black"
      strokeWidth = 2


    with app:
      stage = newStage "board"
      transformer = newTransformer()
      hoverGroup = newGroup()
      mainGroup = newGroup()
      bottomGroup = newGroup()
      tempEdge = newEdge(EdgeConfig())

    with app.stage:
      width = window.innerWidth
      height = window.innerHeight
      on "click", onStageClick
      on "mousedown pointerdown", mouseDownStage
      on "mousemove pointermove", mouseMoveStage
      on "mouseup pointerup", mouseUpStage
      add layer

    with layer:
      add centerCircle 
      add app.bottomGroup
      add app.tempEdge.konva.wrapper
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

    block global_events:
      addEventListener app.stage.container, "wheel", onWheel, nonPassive
      addEventListener app.stage.container, "contextmenu", proc(e: Event) =
        e.preventDefault

      window.document.body.addEventListener "keydown", proc(
          e: Event as KeyboardEvent) {.caster.} =
        if e.key == cstring" ":
          app.isSpaceDown = true
          setCursor ccMove

      window.document.body.addEventListener "keyup", proc(
          e: Event as KeyboardEvent) {.caster.} =
        if app.isSpaceDown:
          app.isSpaceDown = false
          setCursor ccNone

      document.addEventListener "paste", proc(pasteEvent: Event) =
        discard
        # let file = pasteEvent.clipboardData.files[0]

        # if file && file.type.startsWith("image"):
        #   imageDataUrl(file).then(onPasteOnScreen)
        # else:
        #   console.log("WTF")

    block init:
      app.sidebarWidth = defaultWidth
      app.font.family = "Vazirmatn"
      app.font.size = 20
      app.theme = white
      app.edge.theme = white
      app.edge.width = 10.Tenth

    block prepare:
      hide app.tempEdge.konva.wrapper
      moveStage app.stage.center
      redraw()

  block shortcuts:
    addHotkey "delete", proc =
      # console.log app.selectedKonvaObject
      # app.selectedKonvaObject.?destroy
      # app.transformer.nodes = []
      discard

    addHotkey "Escape", proc =
      app.boardState = bsFree
      # TODO do not set points of line by manually, use a function
      hide app.tempEdge.konva.wrapper
      app.footerState = fsOverview
      unselect()
      redraw()

    addHotkey "n", createNode

    # TODO move
    addHotkey "m", proc = discard

    # TODO make connection
    addHotkey "c", proc = discard

    # TODO show/hide side bar
    addHotkey "b", proc = discard
