import std/[with, math, options, lenientops, strformat, random, sets, tables]
import std/[dom, jsconsole, jsffi, asyncjs, sugar]
import karax/[karax, karaxdsl, vdom, vstyles]
import caster, uuid4, questionable, prettyvec

import ../jslib/[konva, hotkeys, axios]
import ./editor/[components, core]
import ../utils/[ui, browser, js]
import ../../common/[conventions, datastructures, types]
import ../../backend/[routes]
import ../../backend/database/[models]


type
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

  Oid = cstring

  Region = range[1..4]

  Axis = enum
    aVertical
    aHorizontal

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

    theme: ColorTheme # TODO use pallete index
    sidebarWidth: Natural

    lastAbsoluteMousePos: Vector
    lastClientMousePos: Vector
    leftClicked: bool

    ## TODO store set of keys that are pressed
    isShiftDown: bool
    isSpaceDown: bool

    # board data
    # TODO pallete: seq[ColorTheme]
    objects: Table[Oid, VisualNode]
    edges: Graph[Oid]
    edgeInfo: Table[Slice[Oid], Edge]

  VisualNode = ref object # TODO add variant image[with or without background]/text
    config*: VisualNodeData
    konva: VisualNodeParts

  VisualNodeParts = object
    wrapper: Group
    box: Rect
    txt: Text

  Edge = ref object
    config: EdgeConfig
    konva: EdgeKonvaNodes

  EdgeKonvaNodes = object
    wrapper: Group
    shape: KonvaShape
    line: Line

  CssCursor = enum
    ccNone = ""
    ccMove = "move"
    ccZoom = "zoom-in"
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

  invalidTheme = c(0, 0, 0)
  white = c(0xffffff, 0x889bad, 0xa5b7cf)
  smoke = c(0xecedef, 0x778696, 0x9eaabb)
  road = c(0xdfe2e4, 0x617288, 0x808fa6)
  yellow = c(0xfef5a6, 0x958505, 0xdec908)
  orange = c(0xffdda9, 0xa7690e, 0xe99619)
  red = c(0xffcfc9, 0xb26156, 0xff634e)
  peach = c(0xfbc4e2, 0xaf467e, 0xe43e97)
  pink = c(0xf3d2ff, 0x7a5a86, 0xc86fe9)
  purple = c(0xdac4fd, 0x7453ab, 0xa46bff)
  purpleLow = c(0xd0d5fe, 0x4e57a3, 0x7886f4)
  blue = c(0xb6e5ff, 0x2d7aa5, 0x399bd3)
  diomand = c(0xadefe3, 0x027b64, 0x00d2ad)
  mint = c(0xc4fad6, 0x298849, 0x25ba58)
  green = c(0xcbfbad, 0x479417, 0x52d500)
  lemon = c(0xe6f8a0, 0x617900, 0xa5cc08)

  colorThemes = [
    white, smoke, road,
    yellow, orange, red,
    peach, pink, purple,
    purpleLow, blue, diomand,
    mint, green, lemon]

  fontFamilies = [
    "Vazirmatn", "cursive", "monospace"]

# TODO use FontFaceObserver
# TODO add hover view when selecting a node
# TODO remove implicit global argument `app` and make it explicit
# TODO add beizier curve
# TODO custom color palletes
var app = AppData()


# ----- Util
template `Δy`*(e): untyped = e.deltaY
template `Δx`*(e): untyped = e.deltaX
template `||`*(v): untyped = v.asScalar

func sorted[T](s: Slice[T]): Slice[T] =
  if s.a < s.b: s
  else: s.b .. s.a

func `or`[S: string or cstring](a, b: S): S =
  if a == "": b
  else: a

template `?`(a): untyped =
  issome a

template `.!`(a, b): untyped =
  a.get.b

template set(vari, data): untyped =
  vari = data


proc applyTheme(txt, box: KonvaObject, theme: ColorTheme) =
  with box:
    fill = $theme.bg
    shadowColor = $theme.st
    shadowOffsetY = 6
    shadowBlur = 8
    shadowOpacity = 0.2

  with txt:
    fill = $theme.fg

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

proc getFocusedFont: FontConfig =
  if v =? app.selectedVisualNode:
    v.config.font
  else:
    app.font

proc setCursor(c: CssCursor) =
  window.document.body.style.cursor = $c

proc setFocusedFontFamily(fn: string) =
  if issome app.selectedVisualNode:
    let v = app.selectedVisualNode.get
    v.config.font.family = fn
    redrawSizeNode v, v.config.font
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

func rectSide(a: Area, r: Region): tuple[axis: Axis, limit: Float] =
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
      else: c1 + onBorder(rectSide(a1 + -c1, r1), θ)
    t =
      if c2 in a1: c1
      else: c2 - onBorder(rectSide(a2 + -c2, r2), θ)

  e.konva.line.points = [c1, c2]
  e.konva.shape.position = (h + t) / 2

proc updateEdgeWidth(e: Edge, w: Tenth) =
  let v = toFloat w
  e.config.width = w
  e.konva.line.strokeWidth = v
  with e.konva.shape:
    strokeWidth = v
    radius = max(6, v * 3)

proc updateEdgeTheme(e: Edge, t: ColorTheme) =
  e.config.theme = t
  e.konva.line.stroke = $t.st
  with e.konva.shape:
    stroke = $t.st
    fill = $t.bg

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

proc redrawConnectionsTo(uid: Oid) =
  for id in app.edges.getOrDefault(uid):
    let
      ei = app.edgeInfo[sorted id..uid]
      ps = ei.konva.line.points.foldPoints
      n1 = app.objects[id]
      n2 = app.objects[uid]

    updateEdge ei, n1.area, n1.center, n2.area, n2.center

proc setText(v: VisualNode, t: cstring) =
  v.config.text = $t
  v.konva.txt.text = t or "  ...  "
  redrawSizeNode v, v.config.font
  redrawConnectionsTo v.config.id

proc setFocusedFontSize(s: int) =
  if v =? app.selectedVisualNode:
    v.config.font.size = s
    redrawSizeNode v, v.config.font
    redrawConnectionsTo v.config.id
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
  if v =? app.selectedVisualNode: v.config.theme
  elif e =? app.selectedEdge: e.config.theme
  else: app.theme

proc setFocusedTheme(theme: ColorTheme) =
  if v =? app.selectedVisualNode:
    v.config.theme = theme
    applyTheme v.konva.txt, v.konva.box, theme
  elif e =? app.selectedEdge:
    updateEdgeTheme e, theme
  else:
    app.theme = theme


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

proc `center=`(stage: Stage, c: Vector) =
  let s = ||stage.scale
  stage.position = -c * s + stage.size.v/2

proc moveStage(v: Vector) =
  app.stage.x = app.stage.x + v.x
  app.stage.y = app.stage.y + v.y

proc changeScale(mouse🖱️: Vector, newScale: Float, changePosition: bool) =
  ## zoom in/out with `real` position pinned
  let
    s′ = clamp(newScale, minScale .. maxScale)

    w = app.stage.width
    h = app.stage.height

    real = coordinate(mouse🖱️, app.stage)
    realϟ = real * s′

  app.stage.scale = s′

  if changePosition:
    app.stage.x = -realϟ.x + w/2
    app.stage.y = -realϟ.y + h/2

    let
      real′ = coordinate(mouse🖱️, app.stage)
      d = real′ - real

    moveStage d * s′

proc incl(t: var Transformer, objs: openArray[KonvaShape], layer: Layer) =
  # t.nodes = objs
  layer.add t
  layer.batchDraw

proc createNode =
  var
    wrapper = newGroup()
    box = newRect()
    txt = newText()
    vn = VisualNode()
    uid = cstring $uuid4()

  with vn.config:
    id = $uid
    font = app.font
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
    text = vn.config.text

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
            id2 = cstring sv.config.id
            conn = sorted id1..id2

          var ei = cloneEdge app.tempEdge

          if conn notin app.edgeInfo:
            app.bottomGroup.add ei.konva.wrapper
            app.edges.addConn conn
            app.edgeInfo[conn] = ei
            app.boardState = bsFree
            select ei
            hide app.tempEdge.konva.wrapper
            removeHighlight sv

      redraw()

  with wrapper:
    x = app.lastAbsoluteMousePos.x
    y = app.lastAbsoluteMousePos.y
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


  app.objects[uid] = vn
  app.mainGroup.getLayer.add wrapper
  select vn
  applyTheme txt, box, vn.config.theme
  setText vn, ""
  redrawSizeNode vn, vn.config.font
  app.sidebarState = ssPropertiesView
  redraw()

proc newPoint(pos: Vector): Circle =
  result = newCircle()
  with result:
    radius = 1
    position = pos

# ----- UI
let compTable = defaultComponents()
var msgCache: Table[Id, cstring]

proc getMsg(id: Id) =
  let q = get_api_note_url(id).getApi
  q.dthen proc(r: AxiosResponse) =
    let
      d = cast[Note](r.data)
      msg = deserizalize(compTable, d.data).innerHtml

    msgCache[id] = msg
    redraw()

proc msgComp(v: VisualNode, i: int, mid: Id): VNode =
  buildHTML:
    tdiv(class = "card mb-4"):
      tdiv(class = "card-body"):
        tdiv(class = "tw-content"):
          if mid in msgCache:
            verbatim msgCache[mid]
          else:
            text "Loading ..."

      tdiv(class = "card-footer d-flex justify-content-center"):
        button(class = "btn mx-1 btn-compact btn-outline-info"):
          icon "fa-link"
          proc onclick =
            discard

        button(class = "btn mx-1 btn-compact btn-outline-primary"):
          icon "fa-sync"
          proc onclick =
            getMsg mid

        button(class = "btn mx-1 btn-compact btn-outline-dark"):
          icon "fa-chevron-up"
          proc onclick =
            if 0 < i:
              swap v.config.messageIdList[i], v.config.messageIdList[i-1]
              redraw()

        button(class = "btn mx-1 btn-compact btn-outline-dark"):
          icon "fa-chevron-down"
          proc onclick =
            if i < v.config.messageIdList.high:
              swap v.config.messageIdList[i+1], v.config.messageIdList[i]
              redraw()

        button(class = "btn mx-1 btn-compact btn-outline-danger"):
          icon "fa-close"
          proc onclick =
            v.config.messageIdList.delete i
            redraw()


proc addToMessages(id: Id) =
  let v = app.selectedVisualNode.get
  if id notin v.config.messageIdList:
    v.config.messageIdList.add id
    getmsg id

proc isMaximized*: bool =
  app.sidebarWidth >= window.innerWidth * 2/3

proc maximize* =
  app.sidebarWidth =
    if isMaximized(): defaultWidth
    else: window.innerWidth
  redraw()

proc sidebarStateMutator*(to: SidebarState): proc =
  proc =
    app.sidebarState = to

proc colorSelectBtn(selectedTheme, theme: ColorTheme, selectable: bool): Vnode =
  buildHTML:
    tdiv(class = "px-1 h-100 d-flex align-items-center " &
      iff(selectedTheme == theme, "bg-light")):
      tdiv(class = "color-square mx-1 pointer", style = style(
        (StyleAttr.backgroundColor, cstring $theme.bg),
        (StyleAttr.borderColor, cstring $theme.fg),
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

  buildHtml:
    tdiv(class = "karax"):
      main(class = "board-wrapper bg-light overflow-hidden h-100 w-100"):
        konva "board"

      footer(class = "regions position-absolute bottom-0 left-0 w-100 bg-white border-top border-dark-subtle"):
        tdiv(class = "inside h-100 d-flex align-items-center", style = style(
            StyleAttr.width, cstring $(window.innerWidth - app.sidebarWidth))):

          tdiv(class = "d-inline-flex jusitfy-content-center align-items-center mx-2"):
            if ?app.selectedVisualNode:
              icon "fa-crosshairs"
            elif ?app.selectedEdge:
              icon "fa-grip-lines"
            else:
              icon "fa-earth-asia"

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

            if not ?app.selectedEdge:

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
          icon "fa-plus fa-lg"

        # TODO show shortcut and name via a tooltip
        button(class = "btn btn-outline-primary border-0 px-3 py-4"):
          icon "fa-expand fa-lg"

        button(class = "btn btn-outline-primary border-0 px-3 py-4"):
          icon "fa-download fa-lg"

      aside(class = "side-bar position-absolute shadow-sm border bg-white h-100 d-flex flex-row " &
          iff(freeze, "user-select-none ") & iff(app.sidebarWidth <
              ciriticalWidth, "icons-only "),
          style = style(StyleAttr.width, fmt"{app.sidebarWidth}px")):

        tdiv(class = "extender h-100 btn btn-light p-0"):
          proc onMouseDown =
            setCursor ccresizex

            winel.onmousemove = proc(e: Event as MouseEvent) {.caster.} =
              let w = window.innerWidth - e.x
              app.sidebarWidth = max(w, minimizeWidth)
              redraw()

            winel.onmouseup = proc(e: Event) =
              window.document.body.style.cursor = ""
              reset winel.onmousemove
              reset winel.onmouseup

        tdiv(class = "d-flex flex-column w-100"):
          header(class = "nav nav-tabs d-flex flex-row justify-content-between align-items-end bg-light mb-2"):

            tdiv(class = "d-flex flex-row"):
              tdiv(class = "nav-item", onclick = sidebarStateMutator ssMessagesView):
                span(class = "nav-link px-3 pointer" &
                    iff(app.sidebarState == ssMessagesView, " active")):
                  span(class = "caption"):
                    text "Messages "
                  icon "fa-message"

              tdiv(class = "nav-item", onclick = sidebarStateMutator ssPropertiesView):
                span(class = "nav-link px-3 pointer" &
                  iff(app.sidebarState == ssPropertiesView, " active")):
                  span(class = "caption"):
                    text "Properties "
                  icon "fa-circle-info"

            tdiv(class = "nav-item d-flex flex-row px-2"):
              span(class = "nav-link px-1 pointer", onclick = maximize):
                invisibleText()

                icon(
                    if isMaximized(): "fa-window-minimize"
                    else: "fa-window-maximize")

          main(class = "p-4 content-wrapper h-100"):
            case app.sidebarState
            of ssMessagesView:
              if sv =? app.selectedVisualNode:
                for i, mid in sv.config.messageIdList:
                  msgComp sv, i, mid

            of ssPropertiesView:
              let vn = app.selectedVisualNode

              if issome vn:
                let obj = vn.get

                tdiv(class = "form-group"):
                  input(`type` = "string", class = "form-control",
                      placeholder = "text ...", value = obj.config.text):

                    proc oninput(e: Event, v: Vnode) =
                      let s = e.target.value
                      setText obj, s

          footer(class = "mt-2"):
            case app.sidebarState
            of ssPropertiesView: discard
            of ssMessagesView:
              if issome app.selectedVisualNode:
                tdiv(class = "input-group"):
                  input(`type` = "text", id = "new-message-input",
                      class = "form-control form-control-sm")
                  button(class = "input-group-text btn btn-primary"):
                    icon "fa-add"
                    proc onClick =
                      let
                        inp = qi "new-message-input"
                        id = parseInt inp.value
                      addToMessages id
                      inp.value = c""

proc init* =
  echo "compiled at: ", CompileDate, ' ', CompileTime
  document.body.classList.add "overflow-hidden"
  setRenderer createDom
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
      add layer

      on "mousedown pointerdown", proc =
        app.leftClicked = true

      on "mouseup pointerup", proc =
        app.leftClicked = false

      on "mousemove pointermove":
        proc(ke: JsObject as KonvaMouseEvent) {.caster.} =
          let
            m = v(ke.evt.x, ke.evt.y)
            s = ||app.stage.scale
            currentMousePos = coordinate(m, app.stage)
            Δy = m.y - app.lastClientMousePos.y

          if app.isShiftDown:
            let
              ⋊s = exp(-Δy / 400)
              s′ = clamp(s * ⋊s, minScale .. maxScale)
              Δs = s′ - s
              mm = app.stage.center

            if Δs.abs > 0.001:
              changeScale mm, s′, false
              app.stage.center = mm - v(app.sidebarWidth/2, 0) * (1/s-1/s′)

          elif app.boardState == bsMakeConnection:
            let
              v = app.hoverVisualNode
              n1 = !app.selectedVisualNode

            if ?v:
              let n2 = !v
              updateEdge app.tempEdge, n1.area, n1.center, n2.area, n2.center
            else:
              let t = newPoint currentMousePos
              updateEdge app.tempEdge, n1.area, n1.center, t.area, t.position


          app.lastAbsoluteMousePos = currentMousePos
          app.lastClientMousePos = m


    with layer:
      add centerCircle
      add app.bottomGroup
      add app.tempEdge.konva.wrapper
      add app.mainGroup
      add app.hoverGroup # FIXME move it to another layer

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
      proc onWheel(e: Event as WheelEvent) {.caster.} =
        preventDefault e

        let mp = v(e.x, e.y)
        app.lastAbsoluteMousePos = coordinate(mp, app.stage)

        if e.ctrlKey: # pinch-zoom
          let
            s = ||app.stage.scale
            ⋊s = exp(-e.Δy / 100)

          changeScale mp, s * ⋊s, true

        else: # panning
          moveStage v(e.Δx, e.Δy) * -1

      addEventListener app.stage.container, "wheel", onWheel, nonPassive
      addEventListener app.stage.container, "contextmenu", proc(e: Event) =
        e.preventDefault

      window.document.body.addEventListener "keydown", proc(
          e: Event as KeyboardEvent) {.caster.} =
        if e.key == cstring" ":
          app.isSpaceDown = true
          setCursor ccMove
        elif e.keyCode == kcj:
          app.isShiftDown = true
          setCursor ccZoom

      window.document.body.addEventListener "keyup", proc(
          e: Event as KeyboardEvent) {.caster.} =
        if app.isSpaceDown or app.isShiftDown:
          app.isSpaceDown = false
          app.isShiftDown = false
          setCursor ccNone

    block prepare:
      app.sidebarWidth = 0
      app.font.family = fontFamilies[1]
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

      addHotkey "n", createNode # TODO make a t

      addHotkey "c", proc = # go to 0,0
        let s = ||app.stage.scale
        app.stage.center = v(0, 0) + v(app.sidebarWidth/2, 0) * 1/s


      addHotkey "z", proc = # reset zoom
        let c = app.stage.center
        changeScale c, 1, false
        app.stage.center = c

      addHotkey "f", proc = # focus
        if v =? app.selectedVisualNode:
          app.stage.center = v.center
          app.stage.x = app.stage.x - app.sidebarWidth/2

      addHotkey "t", proc = # show/hide side bar
        app.sidebarWidth =
          if app.sidebarWidth <= 10: defaultWidth
          else: 0
        redraw()

      addHotkey "p", proc = # scrennshot
        downloadUrl "screenshot.png", app.stage.toDataUrl(1)


when isMainModule: init()
