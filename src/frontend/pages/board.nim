## [Pinch Zoom](https://gist.github.com/Martin-Pitt/2756cf86dca90e179b4e75003d7a1a2b)
## [Touch](https://konvajs.org/docs/sandbox/Multi-touch_Scale_Stage.html)


import std/[with, math, stats, options, lenientops, strformat, sets, tables, random]
import std/[dom, jsconsole, jsffi, asyncjs, jsformdata, cstrutils, sugar]

import karax/[karax, karaxdsl, vdom, vstyles]
import caster, uuid4, questionable, prettyvec

import ../jslib/[konva, hotkeys, fontfaceobserver]
import ./editor/[components, core]
import ../components/[snackbar]
import ../utils/[ui, browser, js, api]
import ../../common/[conventions, datastructures, types, iter]

import ../../backend/database/[models]


randomize()

type
  Oid = cstring

  Region = range[1..4]

  Axis = enum
    aVertical
    aHorizontal

  NOption[T] = options.Option[T]

type
  SideBarState = enum
    ssMessagesView
    ssPropertiesView
    ssBoardProperties

  BoardState = enum
    bsFree
    bsMakeConnection
    bsAddNode

  FooterState = enum
    fsOverview
    fsColor
    fsFontFamily
    fsFontSize
    fsBorderWidth
    fsBorderShape

  AppState = enum
    asNormal
    asPan

  AppData = object
    id: Id ## current board id that is editing
    title: cstring

    # konva states
    stage: Stage
    hoverGroup: Group
    mainGroup: Group
    bottomGroup: Group

    tempEdge: Edge
    tempNode: VisualNode
    # transformer: Transformer
    # selectedKonvaObject: Option[KonvaObject]

    # app states
    hoverVisualNode: NOption[VisualNode]
    selectedVisualNodes: seq[VisualNode]
    # TODO cache connections for speed when draging
    selectedEdges: seq[Edge]

    font: FontConfig
    edge: EdgeConfig

    sidebarState: SideBarState
    boardState: BoardState
    footerState: FooterState

    theme: ColorTheme
    sidebarWidth: Natural

    lastAbsoluteMousePos: Vector
    lastClientMousePos: Vector
    leftClicked: bool

    state: AppState
    pressedKeys: set[KeyCode]

    # board data
    # TODO selectedPalletes: seq[string]
    objects: Table[Oid, VisualNode]
    edgeGraph: Graph[Oid]
    edgeInfo: Table[Slice[Oid], Edge]

  VisualNode = ref object
    config*: VisualNodeConfig
    konva: VisualNodeParts

  VisualNodeParts = object
    wrapper: Group
    box: Rect
    txt: Text
    img: Image

  Edge = ref object
    data: EdgeData
    konva: EdgeKonvaNodes

  EdgeKonvaNodes = object
    wrapper: Group
    shape: KonvaShape
    line: Line

const
  # TODO read these from css
  # TODO define maximum map [boarders to not go further if not nessesarry]
  minScale = 0.10 # minimum amount of scale
  maxScale = 20.0
  defaultWidth = 500
  ciriticalWidth = 400
  minimizeWidth = 360

  nonExistsTheme = c(0, 0, 0)
  fontFamilies = @[
    "Vazirmatn", "Mooli", "Ubuntu Mono"]

# TODO select custom color palletes
# TODO ability to set the center
# TODO add "exploratory mode" where user starts with some nodes and progressively sees all the graph
# TODO customize border radius for nodes
# TODO add beizier curve
# TODO add custom shape for connections
# FIXME image node border radius is depend on font size

var
  app = AppData()
  colorThemes: seq[ColorTheme]

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



proc applyTheme(txt, box: KonvaObject; theme: ColorTheme) =
  with box:
    fill = toColorString theme.bg
    shadowColor = toColorString theme.st
    shadowOffsetY = 6
    shadowBlur = 8
    shadowOpacity = 0.2

  with txt:
    fill = toColorString theme.fg

proc applyFont(txt: KonvaObject; font: FontConfig) =
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

proc redrawSizeNode(v: VisualNode; font: FontConfig) =
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
  case app.selectedVisualNodes.len
  of 1: app.selectedVisualNodes[0].config.font
  else: app.font

proc setCursor(c: CssCursor) =
  window.document.body.style.cursor = $c

proc setFocusedFontFamily(fn: string) =
  case app.selectedVisualNodes.len
  of 0:
    app.font.family = fn
  else:
    for v in app.selectedVisualNodes:
      v.config.font.family = fn
      redrawSizeNode v, v.config.font

proc hover(vn: VisualNode) =
  app.hoverVisualNode = some vn

proc unhover(vn: VisualNode) =
  reset app.hoverVisualNode

proc highlight(vn: VisualNode) =
  vn.konva.wrapper.opacity = 0.5

proc removeHighlight(vn: VisualNode) =
  vn.konva.wrapper.opacity = 1

proc highlight(vn: Edge) =
  vn.konva.wrapper.opacity = 0.5

proc removeHighlight(vn: Edge) =
  vn.konva.wrapper.opacity = 1

proc unselect(vn: VisualNode) =
  removeHighlight vn
  app.selectedVisualNodes.remove vn

proc unselect =
  for v in app.selectedVisualNodes:
    removeHighlight v

  for e in app.selectedEdges:
    removeHighlight e

  reset app.selectedVisualNodes
  reset app.selectedEdges

proc select(vn: VisualNode) =
  add app.selectedVisualNodes, vn
  highlight vn

proc select(e: Edge) =
  if app.selectedVisualNodes.len != 0:
    unselect()

  highlight e
  add app.selectedEdges, e


func onBorder(axis: Axis; limit: float; θ: Degree): Vector =
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

func onBorder(dd: (Axis, float); θ: Degree): Vector =
  onBorder dd[0], dd[1], θ

func rectSide(a: Area; r: Region): tuple[axis: Axis; limit: float] =
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

func whichRegion(θ: Degree; a: Area): Region =
  ## divides the rectangle into 4 regions according to its diameters
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

proc updateEdgePos(e: Edge; a1: Area; c1: Vector; a2: Area; c2: Vector) =
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

  e.konva.line.points = [h, t]
  e.konva.shape.position = (h + t) / 2

proc updateEdgeWidth(e: Edge; w: Tenth) =
  let v = tofloat w
  e.data.config.width = w
  e.konva.line.strokeWidth = v
  with e.konva.shape:
    strokeWidth = v
    radius = max(6, v * 3)

proc updateEdgeTheme(e: Edge; t: ColorTheme) =
  e.data.config.theme = t
  e.konva.line.stroke = toColorString t.st
  with e.konva.shape:
    stroke = toColorString t.st
    fill = toColorString t.bg

proc newEdge(head, tail: Oid; c: EdgeConfig): Edge =
  var k = EdgeKonvaNodes(
    wrapper: newGroup(),
    shape: newCircle(),
    line: newLine())

  with k.line:
    listening = false
    linecap = lcRound

  with k.shape:
    on "mouseenter", proc =
      setCursor ccPointer

    on "mouseleave", proc =
      setCursor ccNone

  with k.wrapper:
    add k.line
    add k.shape

  Edge(
    konva: k,
    data: EdgeData(
      points: [head, tail],
      config: c))

proc addEdgeClick(e: Edge) =
  with e.konva.shape:
    on "click", proc =
      if kcShift notin app.pressedKeys:
        unselect()

      select e
      redraw()

proc cloneEdge(id1, id2: Oid; e: Edge): Edge =
  result = Edge(
    data: EdgeData(
      points: [id1, id2],
      config: e.data.config),
    konva: EdgeKonvaNodes(
      line: Line clone e.konva.line,
      shape: KonvaShape clone e.konva.shape,
      wrapper: newGroup()))

  with result.konva.wrapper:
    add result.konva.line
    add result.konva.shape

  addEdgeClick result

proc redrawConnectionsTo(uid: Oid) =
  for id in app.edgeGraph.getOrDefault(uid):
    let
      ei = app.edgeInfo[sorted id..uid]
      # ps = ei.konva.line.points.foldPoints
      n1 = app.objects[id]
      n2 = app.objects[uid]

    updateEdgePos ei, n1.area, n1.center, n2.area, n2.center

proc setText(v: VisualNode; t: cstring) =
  assert v.config.data.kind == vndkText
  v.config.data.text = $t
  v.konva.txt.text = t or "  ...  "
  redrawSizeNode v, v.config.font
  redrawConnectionsTo v.config.id

proc setDataText =
  case app.selectedVisualNodes.len
  of 1:
    let vn = app.selectedVisualNodes[0]
    if vn.config.data.kind != vndkText:
      vn.config.data = VisualNodeData(kind: vndkText, text: "")
      vn.konva.txt.show
      vn.konva.img.hide
      setText vn, vn.config.data.text
  else:
    discard

proc setDataImage =
  case app.selectedVisualNodes.len
  of 1:
    let vn = app.selectedVisualNodes[0]
    if vn.config.data.kind != vndkImage:
      vn.config.data = VisualNodeData(kind: vndkImage, url: "")
      vn.konva.txt.hide
  else:
    discard

proc scaleImage(v: VisualNode; scale: float) =
  assert v.config.data.kind == vndkImage
  let
    w = v.konva.img.width
    h = v.konva.img.height
    w′ = w * scale
    h′ = h * scale
    pad = min(w′, h′) * 0.05
    # wrapper = v.konva.wrapper

  with v.konva.img:
    width = w′
    height = h′

  # with wrapper: # place it center
  #   x = wrapper.x - w′/2
  #   y = wrapper.y - h′/2

  with v.konva.box:
    x = -pad
    y = -pad
    width = w′ + pad*2
    height = h′ + pad*2

  redrawConnectionsTo v.config.id
  v.config.data.width = v.konva.img.width
  v.config.data.height = v.konva.img.height
  el"scale-range".value = "1"

proc loadImageGen(url: cstring; vn: VisualNode; newSize: bool) =
  newImageFromUrl url:
    proc(imgNode: konva.Image) =
      let
        wi = imgNode.width             # width of image
        hi = imgNode.height            # height of image
        fr =                           # final ratio
          if newSize:
            let
              sc = ||app.stage.scale   # scale
              ws = app.stage.width/sc  # width of screnn
              hs = app.stage.height/sc # height of screen

              wr = min(wi, ws) / wi    # width ratio
              hr = min(hi, hs) / hi    # height ratio
            min(wr, hr)
          else:
            vn.config.data.width / wi

      vn.konva.img.remove
      vn.konva.img = imgNode
      imgNode.listening = false
      vn.konva.wrapper.add imgNode
      scaleImage vn, fr

proc setImageUrl(v: VisualNode; u: cstring) =
  assert v.config.data.kind == vndkImage
  v.config.data.url = $u
  loadImageGen u, v, true

proc setFocusedFontSize(s: int) =
  case app.selectedVisualNodes.len
  of 0:
    app.font.size = s
  else:
    for v in app.selectedVisualNodes:
      v.config.font.size = s
      redrawSizeNode v, v.config.font
      redrawConnectionsTo v.config.id

proc setFocusedEdgeWidth(w: Tenth) =
  case app.selectedEdges.len:
  of 0:
    app.edge.width = w
  else:
    for e in app.selectedEdges:
      updateEdgeWidth e, w


proc getFocusedEdgeWidth: Tenth =
  case app.selectedEdges.len
  of 0:
    app.edge.width
  else:
    app.selectedEdges[0].data.config.width


proc getFocusedTheme: ColorTheme =
  if app.selectedVisualNodes.len == 1: app.selectedVisualNodes[0].config.theme
  elif app.selectedEdges.len == 1: app.selectedEdges[0].data.config.theme
  else: app.theme

proc setFocusedTheme(theme: ColorTheme) =
  var done = false
  for v in app.selectedVisualNodes:
    v.config.theme = theme
    applyTheme v.konva.txt, v.konva.box, theme
    done = true

  for e in app.selectedEdges:
    updateEdgeTheme e, theme
    done = true

  if not done:
    app.theme = theme


func coordinate(mouse: Vector; scale, offsetx, offsety: float): Vector =
  v(
    (-offsetx + mouse.x) / scale,
    (-offsety + mouse.y) / scale)

proc coordinate(pos: Vector; stage: Stage): Vector =
  coordinate pos, ||stage.scale, stage.x, stage.y

func center(scale, offsetx, offsety, width, height: float): Vector =
  ## real coordinate of center of the canvas
  v((width/2 - offsetx) / scale,
    (height/2 - offsety) / scale)

proc center(stage: Stage): Vector =
  ## real coordinate of center of the canvas
  center(
    ||app.stage.scale,
    app.stage.x, app.stage.y,
    app.stage.width, app.stage.height)

proc `center=`(stage: Stage; c: Vector) =
  let s = ||stage.scale
  stage.position = -c * s + stage.size.v/2

proc moveStage(v: Vector) =
  app.stage.x = app.stage.x + v.x
  app.stage.y = app.stage.y + v.y

proc changeScale(mouse🖱️: Vector; newScale: float; changePosition: bool) =
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

proc startAddConn(vn: VisualNode) =
  let w = vn.konva.wrapper
  highlight vn
  show app.tempEdge.konva.wrapper
  updateEdgePos app.tempEdge, w.area, w.center, w.area, w.center
  updateEdgeTheme app.tempEdge, getFocusedTheme()
  updateEdgeWidth app.tempEdge, getFocusedEdgeWidth()
  app.boardState = bsMakeConnection


proc createNode(cfg: VisualNodeConfig): VisualNode =
  unselect()

  var
    wrapper = newGroup()
    box = newRect()
    txt = newText()
    img = newImage()
    vn = VisualNode(config: cfg)
    lastPos = v(0, 0)

  with vn.konva:
    wrapper = wrapper
    box = box
    txt = txt
    img = img

  with txt:
    x = 0
    y = 0
    align = $hzCenter
    listening = false

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
        if vn in app.selectedVisualNodes:
          unselect vn
        elif kcShift in app.pressedKeys:
          select vn
        else:
          unselect()
          select vn

      of bsMakeConnection:
        let sv = app.selectedVisualNodes[0]
        if sv == vn: discard
        else:
          let
            id1 = cfg.id
            id2 = cstring sv.config.id
            conn = sorted id1..id2

          var ei = cloneEdge(id1, id2, app.tempEdge)

          if conn notin app.edgeInfo:
            app.bottomGroup.add ei.konva.wrapper
            app.edgeGraph.addConn conn
            app.edgeInfo[conn] = ei
            app.boardState = bsFree
            select ei
            hide app.tempEdge.konva.wrapper
            removeHighlight sv

      else:
        discard

      redraw()

  with wrapper:
    position = cfg.position
    draggable = true
    add box
    add txt

    on "dragstart", proc = # FIXME sometimes cannot drag no matter selected or not
      if app.state != asNormal or vn notin app.selectedVisualNodes:
        stopDrag wrapper
      else:
        lastpos = wrapper.position
        setCursor ccMove

    on "dragend", proc =
      for v in app.selectedVisualNodes:
        v.config.position = v.konva.wrapper.position # sync data
      setCursor ccPointer

    on "dragmove", proc =
      let Δv = wrapper.position - lastpos
      var seen = false

      for o in app.selectedVisualNodes:
        if o == vn:
          seen = true
        else:
          o.konva.wrapper.move Δv
        redrawConnectionsTo o.config.id

      lastPos = wrapper.position
      if not seen:
        redrawConnectionsTo vn.config.id

  applyTheme txt, box, vn.config.theme

  case vn.config.data.kind
  of vndkText:
    setText vn, vn.config.data.text
  of vndkImage:
    let u = vn.config.data.url
    loadImageGen u, vn, false
  vn

proc currentVisualNodeConfig(uid: cstring = c""): VisualNodeConfig =
  VisualNodeConfig(
    id: uid,
    position: app.lastAbsoluteMousePos,
    font: app.font,
    theme: app.theme,
    data: VisualNodeData(
      kind: vndkText,
      text: ""))

proc createNode: VisualNode =
  let uid = cstring $uuid4()
  let vn = createnode currentVisualNodeConfig(uid)

  app.objects[uid] = vn
  app.sidebarState = ssPropertiesView

  select vn
  redrawSizeNode vn, vn.config.font
  redraw()
  vn

proc toJson(app: AppData): BoardData =
  result.objects = initNTable[Str, VisualNodeConfig]()

  for oid, node in app.objects:
    result.objects[oid] = node.config

  for conn, info in app.edgeInfo:
    result.edges.add EdgeData(
      points: [conn.a, conn.b],
      config: info.data.config)

proc restore(app: var AppData; data: BoardData) =
  for oid, data in data.objects:
    let vn = createNode data
    app.objects[oid] = vn
    app.mainGroup.getLayer.add vn.konva.wrapper

  for info in data.edges:
    let
      id1 = info.points[cpkHead]
      id2 = info.points[cpkTail]
      conn = id1..id2
      n1 = app.objects[conn.a]
      n2 = app.objects[conn.b]
      e = newEdge(id1, id2, info.config)

    app.edgeGraph.addConn conn
    app.edgeInfo[conn] = e
    app.bottomGroup.add e.konva.wrapper
    updateEdgeWidth e, info.config.width
    updateEdgeTheme e, info.config.theme
    updateEdgePos e, n1.area, n1.center, n2.area, n2.center
    addEdgeClick e


proc newPoint(pos: Vector; r = 1.0): Circle =
  result = newCircle()
  with result:
    radius = r
    position = pos

# ----- UI
let compTable = defaultComponents()
var
  noteHtmlContent: Table[Id, Option[cstring]]
  noteRelTags: Table[Id, RelValuesByTagId]
  tags: Table[Id, Tag]


proc getMsg(id: Id) =
  noteHtmlContent[id] = none cstring

  apiGetNote id, proc(n: NoteItemView) =
    deserizalize(compTable, n.data)
    .dthen proc(t: TwNode) =
      noteHtmlContent[id] = some t.dom.innerHtml
      noteRelTags[id] = n.activeRelsValues
      redraw()

type MsgState = enum
  msReady
  msQueue
  msOut

proc msgState(id: Id): MsgState =
  if id in noteHtmlContent:
    let m = noteHtmlContent[id]
    if issome m: msReady
    else: msQueue
  else: msOut

proc msgComp(v: VisualNode; i: int; mid: Id): VNode =
  buildHTML:
    tdiv(class = "card mb-4"):
      tdiv(class = "card-body"):
        tdiv(class = "tw-content"):
          case msgState mid
          of msReady: verbatim get noteHtmlContent[mid]
          of msQueue:
            text "Loading ..."
          of msOut:
            (getMsg mid)
            text "Loading ..."

      if mid in noteRelTags:
        tdiv(class = "m-2"):
          for k, values in noteRelTags[mid]:
            for v in values:
              let id = Id parseInt k
              tagViewC tags[id], v, noop


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
  if app.selectedVisualNodes.len == 1:
    let v = app.selectedVisualNodes[0]
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

proc colorSelectBtn(selectedTheme, theme: ColorTheme; seleNTable: bool): Vnode =
  buildHTML:
    tdiv(class = "px-1 h-100 d-flex align-items-center " &
      iff(selectedTheme == theme, "bg-light")):
      tdiv(class = "mx-1 transparent-pattern-bg"):
        tdiv(class = "color-square pointer", style = style(
          (StyleAttr.backgroundColor, toColorString theme.bg),
          (StyleAttr.borderColor, toColorString theme.fg),
        )):
          proc onclick =
            if seleNTable:
              setFocusedTheme theme
              app.footerState = fsOverview

proc fontSizeSelectBtn[T](size, selected: T; seleNTable: bool; fn: proc()): Vnode =
  buildHTML:
    tdiv(class = "px-1 h-100 d-flex align-items-center " &
      iff(size == selected, "bg-light")):
      tdiv(class = "mx-2 pointer"):
        span:
          text $size

        proc onclick =
          if seleNTable:
            fn()

proc fontFamilySelectBtn(name: string; seleNTable: bool): Vnode =
  buildHTML:
    tdiv(class = "px-1 h-100 d-flex align-items-center " &
      iff(name == app.font.family, "bg-light")):
      tdiv(class = "mx-2 pointer"):
        span:
          text name

        proc onclick =
          if seleNTable:
            setFocusedFontFamily name
            app.footerState = fsOverview

# FIXME duplicate fn from notes_list
func fromJson(s: RelValuesByTagId): Table[Id, seq[cstring]] =
  for k, v in s:
    let id = Id parseInt k
    result[id] = v

proc loadFonts(fontsFamilies: seq[string]): Future[void] =
  newPromise proc(resolve, reject: proc()) =
    var loadEvents: seq[Future[void]]

    for ff in fontsFamilies:
      add loadEvents, load newFontFaceObserver ff

    waitAll loadEvents, resolve

proc loadPalette(palette: string): Future[void] =
  newPromise proc(resolve, reject: proc()) =
    apiGetPalette palette, proc(ct: seq[ColorTheme]) =
      colorThemes = ct
      resolve()

proc fetchBoard(id: Id) =
  apiGetBoard id, proc(b: Board) =
    app.restore b.data
    app.title = b.title

proc fetchTags(): Future[void] =
  newPromise proc(resolve, reject: proc()) =
    apiGetTagsList proc(tagsList: seq[Tag]) =
      for t in tagsList:
        tags[t.id] = t
      resolve()


proc createDom*(data: RouterData): VNode =
  console.info "just updated the whole virtual DOM"
  let freeze = winel.onmousemove != nil

  buildHtml:
    tdiv(class = "karax"):
      main(class = "board-wrapper bg-light overflow-hidden h-100 w-100"):
        konva "board"

      footer(class = "regions position-absolute bottom-0 left-0 w-100 bg-white border-top border-dark-subtle"):
        tdiv(class = "inside h-100 d-flex align-items-center", style = style(
            StyleAttr.width, cstring $(window.innerWidth - app.sidebarWidth))):

          tdiv(class = "d-inline-flex jusitfy-content-center align-items-center mx-2"):
            if app.selectedVisualNodes.len != 0:
              icon "fa-crosshairs"
            elif app.selectedEdges.len != 0:
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
              colorSelectBtn(nonExistsTheme, theme, false)

              proc onclick =
                app.footerState = fsColor
                redraw()

            if app.selectedEdges.len == 0:

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
                colorSelectBtn(getFocusedTheme(), ct, true)

          else:
            text "not defined"

      aside(class = "tool-bar btn-group-vertical position-absolute bg-white border border-secondary border-start-0 rounded-right rounded-0"):
        let n = app.selectedVisualNodes.len

        if n > 1:
          button(class = "btn btn-outline-primary border-0 px-3 py-4"):
            span:
              text $n

        elif n == 1:
          let vn = app.selectedVisualNodes[0]

          button(class = "btn btn-outline-primary border-0 px-3 py-4"):
            icon "fa-circle-nodes"

            proc onclick =
              startAddConn vn

          button(class = "btn btn-outline-primary border-0 px-3 py-4"):
            icon "fa-message"

            proc onclick =
              if app.sidebarWidth <= 10:
                app.sidebarWidth = defaultWidth
                app.sidebarState = ssMessagesView

          button(class = "btn btn-outline-primary border-0 px-3 py-4"):
            icon "fa-info"

            proc onclick =
              if app.sidebarWidth <= 10:
                app.sidebarWidth = defaultWidth
                app.sidebarState = ssPropertiesView

        else:
          button(class = "btn btn-outline-primary border-0 px-3 py-4"):
            icon "fa-plus fa-lg"

            proc onclick =
              app.boardState = bsAddNode
              app.tempNode = createNode()

              app.hoverGroup.add app.tempNode.konva.wrapper
              select app.tempNode


          # TODO show shortcut and name via a tooltip
          button(class = "btn btn-outline-primary border-0 px-3 py-4"):
            icon "fa-expand fa-lg"

          button(class = "btn btn-outline-primary border-0 px-3 py-4"):
            icon "fa-download fa-lg"

      aside(class = "side-bar position-absolute shadow-sm border bg-white h-100 d-flex flex-row " &
          iff(freeze, "user-select-none ") &
          iff(app.sidebarWidth < ciriticalWidth, "icons-only "),
          style = style(StyleAttr.width, fmt"{app.sidebarWidth}px")):

        tdiv(class = "extender h-100 btn btn-light p-0"):
          proc onMouseDown =
            setCursor ccresizex

            winel.onmousemove = proc(e: Event as MouseEvent) {.caster.} =
              let w = window.innerWidth - e.x
              app.sidebarWidth = max(w, minimizeWidth)
              redraw()

            winel.onmouseup = proc(e: Event) =
              setCursor ccNone
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

              tdiv(class = "nav-item", onclick = sidebarStateMutator ssBoardProperties):
                span(class = "nav-link px-3 pointer" &
                  iff(app.sidebarState == ssBoardProperties, " active")):
                  span(class = "caption"):
                    text "board "
                  icon "fa-play"

            tdiv(class = "nav-item d-flex flex-row px-2"):
              span(class = "nav-link px-1 pointer", onclick = maximize):
                invisibleText()

                icon(
                    if isMaximized(): "fa-window-minimize"
                    else: "fa-window-maximize")

              span(class = "nav-link px-1 pointer"):
                invisibleText()
                icon "fa-close"

                proc onclick =
                  app.sidebarWidth = 0

          main(class = "p-2 content-wrapper h-100"):
            case app.sidebarState
            of ssMessagesView:
              if app.selectedVisualNodes.len == 1:
                let sv = app.selectedVisualNodes[0]

                if sv.config.messageIdList.len == 0:
                  text "no messages!"
                else:
                  for i, mid in sv.config.messageIdList:
                    msgComp sv, i, mid

            of ssPropertiesView:
              if app.selectedVisualNodes.len == 1:
                let vn = app.selectedVisualNodes[0]
                tdiv(class = "form-group"):
                  fieldset(class = "form-group"):
                    legend(class = "mt-4"):
                      text "Type Of Node"

                    tdiv(class = "form-check"):
                      input(`type` = "radio",
                          class = "form-check-input",
                          value = "option1",
                          onclick = setDataText,
                          checked = vn.config.data.kind == vndkText,
                          name = "kindOfData")

                      label(class = "form-check-label"):
                        text "Text Node"

                    tdiv(class = "form-check"):
                      input(`type` = "radio",
                          class = "form-check-input",
                          value = "option2",
                          onclick = setDataImage,
                          checked = vn.config.data.kind == vndkImage,
                          name = "kindOfData")

                      label(class = "form-check-label"):
                        text "Image Node"

                case vn.config.data.kind
                of vndkText:
                  input(`type` = "text", class = "form-control",
                      placeholder = "text ...", value = vn.config.data.text):

                    proc oninput(e: Event; v: Vnode) =
                      let s = e.target.value
                      setText vn, s

                of vndkImage:
                  input(`type` = "text", class = "form-control",
                      placeholder = "URL", value = vn.config.data.url, name = "url"):

                    proc oninput(e: Event; v: Vnode) =
                      let s = e.target.value
                      setImageUrl vn, s

                  label(class = "form-label"):
                    text "scale"
                  input(`type` = "range", id = "scale-range",
                      class = "form-range", value = "1.0", min = "0.01",
                          max = "3.0", step = "0.01"):
                    proc onchange(e: Event; v: Vnode) =
                      let s = e.target.value
                      scaleImage vn, parseFloat s

            of ssBoardProperties:
              label(class = "form-label"):
                text "Title"

              input(`type` = "text", class = "form-control",
                    placeholder = "title", value = app.title):

                proc oninput(e: Event; v: Vnode) =
                  let s = e.target.value
                  app.title = s

              button(class = "btn btn-primary m-2"):
                text "update"
                icon "fa-sync ms-2"

                proc onclick =
                  apiUpdateBoardTitle app.id, $app.title, proc =
                    notify "title updated!"


          footer(class = "mt-2"):
            case app.sidebarState
            of ssMessagesView:
              if app.selectedVisualNodes.len > 0:
                tdiv(class = "input-group"):
                  input(`type` = "text", id = "new-message-input",
                      class = "form-control form-control-sm")
                  button(class = "input-group-text btn btn-primary"):
                    icon "fa-add"
                    proc onClick =
                      let
                        inp = el"new-message-input"
                        id = parseInt inp.value
                      addToMessages id
                      inp.value = c""
            else: discard


      snackbar()

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
      # transformer = newTransformer()
      hoverGroup = newGroup()
      mainGroup = newGroup()
      bottomGroup = newGroup()
      tempEdge = newEdge("[temp]", "[temp]", EdgeConfig())
      # tempNode: VisualNode

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

          if kcJ in app.pressedKeys:
            let
              ⋊s = exp(-Δy / 400)
              s′ = clamp(s * ⋊s, minScale .. maxScale)
              Δs = s′ - s
              mm = app.stage.center

            if Δs.abs > 0.001:
              changeScale mm, s′, false
              app.stage.center = mm - v(app.sidebarWidth/2, 0) * (1/s - 1/s′)

          case app.boardState
          of bsMakeConnection:
            let
              v = app.hoverVisualNode
              n1 = app.selectedVisualNodes[0]

            if ?v:
              let n2 = !v
              updateEdgePos app.tempEdge, n1.area, n1.center, n2.area, n2.center
            else:
              let t = newPoint currentMousePos
              updateEdgePos app.tempEdge, n1.area, n1.center, t.area, t.position

          of bsAddNode:
            app.tempNode.konva.wrapper.position = currentMousePos
            app.tempNode.config.position = currentMousePos

          else:
            discard

          app.lastAbsoluteMousePos = currentMousePos
          app.lastClientMousePos = m

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
        if app.leftClicked and (kcSpace in app.pressedKeys):
          moveStage movement e

      on "mouseup", proc =
        app.leftClicked = false

        case app.boardState
        of bsAddNode:
          if app.state == asNormal:
            app.boardState = bsFree
            app.objects[app.tempNode.config.id] = app.tempNode
            app.mainGroup.add app.tempNode.konva.wrapper
            app.tempNode = nil
            unselect()
        else:
          discard


    block global_events:
      addEventListener app.stage.container, "wheel", nonPassive:
        proc (e: Event as WheelEvent) {.caster.} =
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

      addEventListener app.stage.container, "contextmenu":
        proc(e: Event) =
          e.preventDefault

      addEventListener document.body, "keydown":
        proc(e: Event as KeyboardEvent) {.caster.} =
          let kc = e.keyCode.KeyCode
          app.pressedKeys.incl kc

          case kc
          of kcSpace:
            setCursor ccGrabbing
            app.state = asPan

          of kcJ:
            setCursor ccZoom

          else:
            discard

      addEventListener document.body, "keyup":
        proc(e: Event as KeyboardEvent) {.caster.} =
          let kc = KeyCode e.keyCode
          app.pressedKeys.excl kc

          if app.pressedKeys.len == 0:
            setCursor ccNone
            app.state = asNormal

      addEventListener document.body, "paste":
        proc(e: Event as ClipboardEvent) {.caster.} =

          let
            s = e.text
            files = e.clipboardData.filesArray

          if s.startswith "/": # paste by link
            let vn = createNode()
            loadImageGen s, vn, true

          elif files.len == 1: # paste by image
            let f = files[0]
            if f.`type`.startswith "image/":
              apiUploadAsset toForm(f.name, f), proc(assetUrl: string) =
                let vn = createNode()

                vn.config.data = VisualNodeData(
                  kind: vndkImage,
                  url: assetUrl)

                loadImageGen assetUrl, vn, true

    block prepare:
      app.sidebarWidth = 0
      app.font.family = fontFamilies[1]
      app.font.size = 20
      app.theme = nonExistsTheme
      app.edge.theme = nonExistsTheme
      app.edge.width = 10.Tenth

    block init:
      hide app.tempEdge.konva.wrapper
      moveStage app.stage.center
      redraw()

    block shortcuts:
      addHotkey "delete", proc =
        if app.selectedVisualNodes.len > 0:
          for vn in app.selectedVisualNodes:
            let oid = vn.config.id

            for n in app.edgeGraph.getOrDefault(oid):
              let key = sorted oid..n
              destroy app.edgeInfo[key].konva.wrapper
              del app.edgeInfo, key

            destroy vn.konva.wrapper
            del app.objects, oid
            removeNode app.edgeGraph, oid

          unselect()
          redraw()


        elif app.selectedEdges.len > 0:
          for ed in app.selectedEdges:
            let
              p = ed.data.points
              conn = sorted p[cpkHead]..p[cpkTail]

            destroy app.edgeInfo[conn].konva.wrapper
            del app.edgeInfo, conn
            removeConn app.edgeGraph, conn

          unselect()
          redraw()

        else:
          notify "nothing to delete"

      addHotkey "Escape", proc =

        if app.boardState == bsAddNode:
          destroy app.tempNode.konva.wrapper

        app.boardState = bsFree
        app.footerState = fsOverview
        hide app.tempEdge.konva.wrapper

        unselect()
        redraw()

      addHotkey "n", proc =
        discard createNode()

      addHotkey "k", proc =
        # echo getClientRect app.mainGroup
        discard

      addHotkey "c", proc = # go to center
        let s = ||app.stage.scale
        app.stage.center = v(0, 0) + v(app.sidebarWidth/2, 0) * 1/s

      addHotkey "s", proc = # save
        apiUpdateBoardContent app.id, forceJsObject toJson app, proc =
          notify "saved!"

      addHotkey "z", proc = # reset zoom
        let c = app.stage.center
        changeScale c, 1, false
        app.stage.center = c

      addHotkey "f", proc = # focus
        if app.selectedVisualNodes.len == 1:
          let v = app.selectedVisualNodes[0]
          app.stage.center = v.center
          app.stage.x = app.stage.x - app.sidebarWidth/2

      addHotkey "t", proc = # show/hide side bar
        app.sidebarWidth =
          if app.sidebarWidth <= 10: defaultWidth
          else: 0
        redraw()

      addHotkey "p", proc = # scrennshot
        app.stage.toBlob(1/2).dthen proc(b: Blob) =
          apiUpdateBoardScrenshot app.id, toForm("screenshot.png", b), proc =
            notify "screenshot updated!"

    app.id = parseInt getWindowQueryParam "id"

    waitAll [loadPalette "default", loadFonts fontFamilies, fetchTags()], proc =
      fetchBoard app.id
      setFocusedTheme sample colorThemes
      redraw()

when isMainModule: init()
