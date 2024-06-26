## Pinch Zoom: https://gist.github.com/Martin-Pitt/2756cf86dca90e179b4e75003d7a1a2b
## Touch:      https://konvajs.org/docs/sandbox/Multi-touch_Scale_Stage.html


import std/[with, math, stats, options, lenientops, strutils, strformat,
    sequtils, sets, tables, random]
import std/[dom, jsconsole, jsffi, asyncjs, jsformdata, cstrutils, sugar]

import karax/[karax, karaxdsl, vdom, vstyles]
import caster, questionable, prettyvec

import ../jslib/[konva, fontfaceobserver]
import ./editor/[components, core]
import ../components/[snackbar, simple, pro]
import ../utils/[browser, js, api, shortcuts]
import ../../common/[conventions, datastructures, types, iter]

import ../../backend/database/[models]
import ../../backend/routes


type
  NOption[T] = options.Option[T]

type
  SideBarState = enum
    ssMessagesView
    ssPropertiesView
    ssShortcuts

  BoardState = enum
    bsFree
    bsMakeConnection
    bsAddNode

  FooterState = enum
    fsOverview
    fsPalette
    fsColor
    fsFontFamily
    fsFontSize
    fsBorderWidth
    fsBorderShape

  AppState = enum
    asNormal
    asPan

  SelectMode = enum
    smSingle
    smAreaNodes
    smAreaEdges

  AppData = object
    id: Id ## current board id that is editing
    title: cstring
    maxNodeId: int
    locked: bool = true
    loading: bool

    # konva states
    stage: Stage
    hoverGroup: Group
    mainGroup: Group
    bottomGroup: Group

    tempEdges: seq[Edge]
    tempNode: VisualNode
    areaSelectionNode: KonvaShape

    # app states
    hoverVisualNode: NOption[VisualNode]
    selectedVisualNodes: seq[VisualNode]
    # TODO cache connections for speed up when draging
    selectedEdges: seq[Edge]

    font: FontConfig
    edge: EdgeConfig

    sidebarState: SideBarState
    boardState: BoardState
    footerState: FooterState

    palettes: seq[Palette]
    selectedPalleteI: int
    theme: ColorTheme

    sidebarWidth: Natural
    sidebarVisible: bool

    selectMode: SelectMode
    panKeyHold: bool
    zoomKeyHold: bool

    lastTouches: seq[Touch]
    lastAbsoluteMousePos: Vector
    lastClientMousePos: Vector
    leftClicked: bool

    state: AppState
    pressedKeys: set[KeyCode]
    actionsShortcutRegistery: ActionsShortcutRegistery

    # board data
    objects: Table[Id, VisualNode]
    edgeGraph: Graph[Id]
    edgeInfo: Table[Slice[Id], Edge]

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

  FontTest = tuple
    name: string
    test: string


  ActionKind = enum
    akDelete
    akCancel
    akZoomMode
    akPanMode
    akOpenCloseSidebar
    akToggleLock
    akCreateNode
    akCreateConnection
    akSave
    akGoCenter
    akUpdateScreenShot
    akResetZoom
    akFocus
    akDownload
    akCopyStyle
    akAreaSelectOptions


  ActionsShortcutRegistery =
    array[ActionKind, ShortCut]

const
  # TODO read these from css
  # TODO define maximum map [boarders to not go further if not nessesarry]
  zoomStep = 200
  minScale = 0.05 # minimum amount of scale
  maxScale = 20.0
  ciriticalWidth = 460
  pinchRatioLimit = 0.75 .. 1.25

  nonExistsTheme = c(0, 0, 0)
  fontFamilies: seq[FontTest] = @[
    ("Vazirmatn", "سلام"), ("Mooli", "teshey"), ("Ubuntu Mono", "hey")]

# FIXME do not make 2 types of nodes. only 1 type with optional image url
# FIXME image node border radius is depend on font size
# TODO define +/- buttons next to size selector to change size of all of the selected nodes to next level
# TODO add a shortcut named 'guide connections', when clicked some arrows are displayed around it that if you click on them you will go to the correspoding neighbour node
# TODO add "exploratory mode" where all nodes' content are hidden when you click they show up

var
  app = AppData()


app.actionsShortcutRegistery = [
  akDelete: sc"DEL",
  akCancel: sc"ESC",
  akZoomMode: sc"J",
  akPanMode: sc"SPC",
  akOpenCloseSidebar: sc"T",
  akToggleLock: sc"L",
  akCreateNode: sc"N",
  akCreateConnection: sc"Q",
  akSave: sc"S",
  akGoCenter: sc"C",
  akUpdateScreenShot: sc"P",
  akResetZoom: sc"Z",
  akFocus: sc"F",
  akDownload: sc"D",
  akCopyStyle: sc"K",
  akAreaSelectOptions: sc"M"]

# ----- Util
template `<>`*(a, b): untyped = clamp(a, b)
template `Δy`*(e): untyped = e.deltaY
template `Δx`*(e): untyped = e.deltaX
template `||`*(v): untyped = v.asScalar

func `or`[S: string or cstring](a, b: S): S =
  if a == "": b
  else: a

template `?`(a): untyped =
  issome a


func coordinate(mouse: Vector; scale, offsetx, offsety: float): Vector =
  v(
    (-offsetx + mouse.x) / scale,
    (-offsety + mouse.y) / scale)

proc coordinate(pos: Vector; stage: Stage): Vector =
  coordinate pos, ||stage.scale, stage.x, stage.y

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

proc setCursor(c: CssCursor) =
  window.document.body.style.cursor = $c

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
  if 0 == app.selectedVisualNodes.len:
    app.state = asNormal

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

proc selectImpl(e: Edge) =
  highlight e
  add app.selectedEdges, e

proc select(e: Edge) =
  if app.selectedVisualNodes.len != 0:
    unselect()
  selectImpl e

proc select(es: seq[Edge]) =
  for e in es:
    selectImpl e

proc newPoint(pos: Vector; r = 1.0): Circle =
  result = newCircle()
  with result:
    radius = r
    position = pos

proc updateEdgePos(e: Edge; a1: Area; c1: Vector; a2: Area; c2: Vector) =
  let
    d = c1 - c2
    θ = arctan d
    r1 = whichRegion(θ, a1)
    r2 = whichRegion(θ, a2)
    h =
      if c2 in a1: c1
      else: c1 - onBorder(rectSide(a1 + -c1, r1), θ)
    t =
      if c2 in a1: c1
      else: c2 + onBorder(rectSide(a2 + -c2, r2), θ)

  e.konva.line.points = [h, t]
  e.konva.shape.position = (h + t) / 2
  e.konva.shape.rotation = float -θ

const
  diomandPoints = @[
    vec2(-1.7, 0),
    vec2(0, +1),
    vec2(+1.7, 0),
    vec2(0, -1)] * 3.2

  trianglePoints = @[
    vec2(-1, +1),
    vec2(+1, 0),
    vec2(-1, -1),
    ] * 3.2

  doubleTrianglePoints = @[
    vec2(0, +1),
    vec2(1.7, 0),
    vec2(0, -1),
    vec2(0, -2),
    vec2(+3.4, 0),
    vec2(0, +2),
    vec2(0, +1),
    vec2(-1.7, +2),
    vec2(-1.7, -2),
    vec2(+1.7, 0),
    ] * 2.8

func newDiomand: Line =
  result = newLine()
  with result:
    points = diomandPoints
    closed = true

func newTriangle: Line =
  result = newLine()
  with result:
    points = trianglePoints
    closed = true

func newDoubleTriangle: Line =
  result = newLine()
  with result:
    points = doubleTrianglePoints
    closed = true

func initCenterShape(cs: ConnectionCenterShapeKind): KonvaShape =
  case cs:
  of ccsCircle: newCircle()
  of ccsSquare: newRect()
  of ccsDiamond: newDiomand()
  of ccsTriangle: newTriangle()
  of ccsDoubleTriangle: newDoubleTriangle()

proc updateEdgeConnSize(sh: KonvaShape; v: float;
    cs: ConnectionCenterShapeKind) =
  sh.strokeWidth = v

  case cs
  of ccsCircle:
    sh.radius = max(6, v * 3)
  of ccsDiamond:
    sh.points = diomandPoints * max(1.8, v)
  of ccsSquare:
    with sh:
      width = v * 5
      height = v * 5
      offsetX = sh.width/2
      offsetY = sh.height/2
  of ccsTriangle:
    sh.points = trianglePoints * max(1.8, v)
  of ccsDoubleTriangle:
    sh.points = doubleTrianglePoints * max(1, v * 0.65)

proc updateEdgeWidth(e: Edge; w: Tenth) =
  let v = tofloat w
  e.data.config.width = w
  e.konva.line.strokeWidth = v
  updateEdgeConnSize e.konva.shape, v, e.data.config.centerShape

proc updateEdgeTheme(e: Edge; t: ColorTheme) =
  e.data.config.theme = t
  e.konva.line.stroke = toColorString t.st
  with e.konva.shape:
    stroke = toColorString t.st
    fill = toColorString t.bg

proc addEdgeEvents(e: Edge) =
  with e.konva.shape:
    on "mouseenter", proc =
      setCursor ccPointer

    on "mouseleave", proc =
      setCursor ccNone

    on "click tap", proc =
      if kcShift notin app.pressedKeys:
        unselect()

      select e
      redraw()

proc cloneEdge(id1, id2: Id; e: Edge): Edge =
  result = Edge(
    data: EdgeData(
      points: @[id1, id2],
      config: e.data.config),
    konva: EdgeKonvaNodes(
      line: Line clone e.konva.line,
      shape: KonvaShape clone e.konva.shape,
      wrapper: newGroup()))

  with result.konva.wrapper:
    add result.konva.line
    add result.konva.shape

  addEdgeEvents result

proc redrawConnectionsTo(uid: Id) =
  for id in app.edgeGraph.getOrDefault(uid):
    let
      c1 = id..uid
      c2 = uid..id

      k =
        if c1 in app.edgeInfo: c1
        else: c2

      ei = app.edgeInfo[k]
      n1 = app.objects[k.a]
      n2 = app.objects[k.b]

    updateEdgePos ei, n1.area, n1.center, n2.area, n2.center

proc changeSelectionMode =
  incRound app.selectMode
  redraw()

proc updateEdgeShape(e: Edge; cs: ConnectionCenterShapeKind) =
  e.data.config.centerShape = cs
  destroy e.konva.shape
  e.konva.shape = initCenterShape(cs)
  add e.konva.wrapper, e.konva.shape

  updateEdgeWidth e, e.data.config.width
  updateEdgeTheme e, e.data.config.theme
  addEdgeEvents e
  redrawConnectionsTo e.data.points[0]

proc applyTheme(txt, box: KonvaObject; theme: ColorTheme) =
  with box:
    fill = toColorString theme.bg
    stroke = toColorString theme.st

  with txt:
    fill = toColorString theme.fg

proc applyFont(txt: KonvaObject; font: FontConfig) =
  with txt:
    fontFamily = font.family
    fontSize = font.size

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
    strokeWidth = font.size / 10
    cornerRadius = pad

proc getFocusedFontFamily: FontConfig =
  case app.selectedVisualNodes.len
  of 0: app.font
  else: app.selectedVisualNodes[0].config.font

proc setFocusedFontFamily(fn: string) =
  case app.selectedVisualNodes.len
  of 0:
    app.font.family = fn
  else:
    for v in app.selectedVisualNodes:
      v.config.font.family = fn
      redrawSizeNode v, v.config.font

proc newEdge(head, tail: Id; c: EdgeConfig): Edge =
  var k = EdgeKonvaNodes(
    wrapper: newGroup(),
    shape: initCenterShape(c.centerShape),
    line: newLine())

  with k.line:
    listening = false
    linecap = lcRound
    perfectDrawEnabled = false
    shadowForStrokeEnabled = false

    # on "mousemove", proc(e: JsObject as KonvaMouseEvent) {.caster.} =
    #   let
    #     m = v(e.evt.x, e.evt.y)
    #     currentMousePos = coordinate(m, app.stage)

    #   k.shape.position = currentMousePos

  with k.wrapper:
    add k.line
    add k.shape

  Edge(
    konva: k,
    data: EdgeData(
      points: @[head, tail],
      config: c))

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
  proc success(imgNode: konva.Image) =
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

  proc fail =
    # TODO set a text node named "[image]" and add a error list and
    # show it in the properties of board
    discard

  newImageFromUrl url, success, fail

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
  of 0: app.edge.width
  else: app.selectedEdges[0].data.config.width

proc getFocusedTheme: ColorTheme =
  if app.selectedVisualNodes.len != 0: app.selectedVisualNodes[0].config.theme
  elif app.selectedEdges.len != 0: app.selectedEdges[0].data.config.theme
  else: app.theme

proc setFocusedConnShape(cs: ConnectionCenterShapeKind) =
  case len app.selectedEdges
  of 0:
    app.edge.centerShape = cs
  else:
    for e in app.selectedEdges:
      updateEdgeShape e, cs

proc getFocusedConnShape: ConnectionCenterShapeKind =
  case app.selectedEdges.len
  of 0: app.edge.centerShape
  else: app.selectedEdges[0].data.config.centerShape

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

proc pos(t: Touch): Vector =
  vec2(toFloat t.clientX, toFloat t.clientY)

func center(s: seq[Touch]): Vector =
  center map(s, pos)

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
    s′ = newScale <> minScale..maxScale

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


proc changeEdgeDirection(e: Edge) =
  let
    conn = e.data.points
    a = conn[0]
    b = conn[1]

  removeConn app.edgeGraph, a..b
  del app.edgeInfo, a..b

  addConn app.edgeGraph, b..a
  app.edgeInfo[b..a] = e
  e.data.points = @[b, a]

  redrawConnectionsTo a

proc changeEdgesDirection(es: openArray[Edge]) =
  for e in es:
    changeEdgeDirection e


proc removeTempEdges =
  for e in app.tempEdges:
    destroy e.konva.wrapper
  reset app.tempEdges

proc startAddConnImpl(vn: VisualNode; tempEdge: Edge; mouse: Vector) =
  let w = vn.konva.wrapper

  highlight vn
  updateEdgePos tempEdge, w.area, w.center, area mouse, mouse
  updateEdgeTheme tempEdge, getFocusedTheme()
  updateEdgeWidth tempEdge, getFocusedEdgeWidth()

proc startAddConns(vns: openArray[VisualNode]) =
  removeTempEdges()

  for vn in vns:
    let e = newEdge(vn.config.id, -1, app.edge)
    add app.tempEdges, e
    add app.bottomGroup, e.konva.wrapper
    startAddConnImpl vn, e, app.lastClientMousePos

  app.selectMode = smSingle
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
    touchMoved = false

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
    perfectDrawEnabled = false

  proc boxClick =
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
      var edges: seq[Edge]

      for i, sv in app.selectedVisualNodes:
        if sv == vn: discard
        else:
          let
            id1 = cfg.id
            id2 = sv.config.id
            conn = id1..id2
            ei = cloneEdge(id1, id2, app.tempEdges[i])

          add edges, ei

          if conn notin app.edgeInfo:
            add app.bottomGroup, ei.konva.wrapper
            addConn app.edgeGraph, conn
            app.edgeInfo[conn] = ei
            app.boardState = bsFree
            removeHighlight sv
            redrawConnectionsTo sv.config.id

      removeTempEdges()
      select edges
    else:
      discard

    redraw()

  with box:
    perfectDrawEnabled = false
    shadowForStrokeEnabled = false

    on "mouseover", proc =
      hover vn
      setCursor ccPointer

    on "mouseleave", proc =
      unhover vn
      setCursor ccNone

    on "click tap", boxClick

    on "touchmove", proc =
      touchMoved = true

    on "touchend", proc =
      reset touchMoved

  with wrapper:
    position = cfg.position
    draggable = true
    add box
    add txt

    on "dragstart", proc =
      if
        app.locked or
        app.state != asNormal or
        vn notin app.selectedVisualNodes:
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

proc currentVisualNodeConfig(uid: Id): VisualNodeConfig =
  VisualNodeConfig(
    id: uid,
    position: app.lastAbsoluteMousePos,
    font: app.font,
    theme: app.theme,
    data: VisualNodeData(
      kind: vndkText,
      text: ""))

proc createNode: VisualNode =
  inc app.maxNodeId
  let uid = app.maxNodeId
  let vn = createnode currentVisualNodeConfig(uid)

  app.objects[uid] = vn
  app.sidebarState = ssPropertiesView

  select vn
  redrawSizeNode vn, vn.config.font
  redraw()
  vn

proc startPuttingNode =
  app.boardState = bsAddNode
  app.tempNode = createNode()

  app.hoverGroup.add app.tempNode.konva.wrapper

proc deleteSelectedNodes =
  for vn in app.selectedVisualNodes:
    let id = vn.config.id

    destroy vn.konva.wrapper
    del app.objects, id

    for n in app.edgeGraph.getOrDefault(id):
      let
        k1 = id..n
        k2 = n..id
        key =
          if k1 in app.edgeInfo: k1
          else: k2

      destroy app.edgeInfo[key].konva.wrapper
      del app.edgeInfo, key

    removeNode app.edgeGraph, id

  for ed in app.selectedEdges:
    let
      p = ed.data.points
      conn = p[ord cpkHead]..p[ord cpkTail]

    destroy app.edgeInfo[conn].konva.wrapper
    del app.edgeInfo, conn
    removeConn app.edgeGraph, conn

  unselect()

proc toJson(app: AppData): BoardData =
  result.objects = initNTable[Str, VisualNodeConfig]()

  for id, node in app.objects:
    result.objects[toCstring id] = node.config

  for conn, info in app.edgeInfo:
    add result.edges, EdgeData(
      points: @[conn.a, conn.b],
      config: info.data.config)

proc restore(app: var AppData; data: BoardData) =
  for id, data in data.objects:
    app.maxNodeId = max(app.maxNodeId, parseInt id)
    let vn = createNode data
    app.objects[parseInt id] = vn
    app.mainGroup.getLayer.add vn.konva.wrapper

  for info in data.edges:
    let
      id1 = info.points[ord cpkHead]
      id2 = info.points[ord cpkTail]
      conn = id1..id2
      n1 = app.objects[conn.a]
      n2 = app.objects[conn.b]
      e = newEdge(id1, id2, info.config)

    addConn app.edgeGraph, conn
    app.edgeInfo[conn] = e
    add app.bottomGroup, e.konva.wrapper
    updateEdgeWidth e, info.config.width
    updateEdgeTheme e, info.config.theme
    updateEdgePos e, n1.area, n1.center, n2.area, n2.center
    addEdgeEvents e


# ----- UI
let compTable = defaultComponents()
var
  noteHtmlContent: Table[Id, Option[cstring]]
  noteRelTags: Table[Id, seq[RelMinData]]
  tags: Table[Str, Tag]

proc getMsg(id: Id) =
  noteHtmlContent[id] = none cstring

  apiGetNote id, proc(n: NoteItemView) =
    deserizalize(compTable, n.data)
    .dthen proc(t: TwNode) =
      noteHtmlContent[id] = some t.dom.innerHtml
      noteRelTags[id] = n.rels
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

# TODO make it a separate component in a different file
proc msgComp(v: VisualNode; i: int; mid: Id): VNode =
  let
    inner = buildHTML:
      tdiv(class = "tw-content"):
        case msgState mid
        of msReady:
          verbatim get noteHtmlContent[mid]
        of msQueue:
          text "Loading ..."
        of msOut:
          (getMsg mid)
          text "Loading ..."

  proc syncMsg =
    getMsg mid

  proc copyMsgId =
    copyToClipboard $mid

  proc moveUp =
    if 0 < i:
      swap v.config.messageIdList[i], v.config.messageIdList[i-1]

  proc moveDown =
    if i < v.config.messageIdList.high:
      swap v.config.messageIdList[i+1], v.config.messageIdList[i]

  proc delMsgFromLisp =
    v.config.messageIdList.delete i

  var btns = @[
    generalCardBtnLink("fa-glasses", "info", get_note_preview_url mid),
    generalCardBtnAction("fa-sync", "primary", syncMsg)]

  if not app.locked:
    add btns, [
      generalCardBtnAction("fa-copy", "primary", copyMsgId),
      generalCardBtnLink("fa-pen", "warning", get_note_editor_url mid),
      generalCardBtnAction("fa-chevron-up", "dark", moveUp),
      generalCardBtnAction("fa-chevron-down", "dark", moveDown),
      generalCardBtnAction("fa-close", "danger", delMsgFromLisp)]

  generalCardView "", inner, getOrDefault(noteRelTags, mid, @[]), tags, btns

proc genSelectPalette(i: int): proc() =
  proc =
    app.selectedPalleteI = i
    app.footerState = fsColor

proc addToMessages(id: Id) =
  if app.selectedVisualNodes.len == 1:
    let v = app.selectedVisualNodes[0]
    if id notin v.config.messageIdList:
      v.config.messageIdList.add id
      getmsg id


proc minSidebarWidth: int =
  min 360, window.innerWidth * 5 div 10

proc defaultWidth: int =
  min 500, window.innerwidth

proc isMaximized: bool =
  window.innerWidth - 20 < app.sidebarWidth

proc maximize =
  app.sidebarWidth =
    if isMaximized(): defaultWidth()
    else: window.innerWidth
  redraw()

proc reconsiderSideBarWidth =
  app.sidebarwidth =
    min(
      max(
        app.sidebarwidth,
        minSidebarWidth()),
      window.innerWidth)

proc onclicker(ct: ConnectionCenterShapeKind): proc() =
  proc =
    setFocusedConnShape ct
    app.footerState = fsOverview

proc reconsiderSideBarWidth(newWidth: int) =
  app.sidebarwidth = newWidth
  reconsiderSideBarWidth()

proc closeSideBar =
  app.sidebarVisible = false

proc openSideBar =
  ## we have to check the width to prevent problems after screen rotation or resize
  app.sidebarVisible = true
  reconsiderSideBarWidth()

proc toggleLock =
  negate app.locked

proc sidebarStateMutator*(to: SidebarState): proc =
  proc =
    app.sidebarState = to

proc colorSelectBtn(selectedTheme, theme: ColorTheme; selectable: bool): Vnode =
  buildHTML:
    tdiv(class = "px-1 h-100 d-flex align-items-center " &
      iff(selectedTheme == theme, "bg-light")):
      tdiv(class = "mx-1 transparent-pattern-bg"):
        tdiv(class = "color-square pointer", style = style(
          (StyleAttr.backgroundColor, toColorString theme.bg),
          (StyleAttr.borderColor, toColorString theme.fg),
        )):
          proc onclick =
            if selectable:
              setFocusedTheme theme
              app.footerState = fsOverview

proc fontSizeSelectBtn[T](size, selected: T; selectable: bool; fn: proc()): Vnode =
  buildHTML:
    tdiv(class = "px-1 h-100 d-flex align-items-center " &
      iff(size == selected, "bg-light")):
      tdiv(class = "mx-2 pointer"):
        span:
          text $size

        proc onclick =
          if selectable:
            fn()

proc fontFamilySelectBtn(name: string; selectable: bool): Vnode =
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

proc loadFonts(fontFamilies: seq[FontTest]): Future[void] =
  newPromise proc(resolve, reject: proc()) =
    var loadEvents: seq[Future[void]]

    for f in fontFamilies:
      add loadEvents, load(newFontFaceObserver f.name, f.test)

    waitAll loadEvents, resolve

proc loadPalettes(): Future[void] =
  newPromise proc(resolve, reject: proc()) =
    apiListPalettes proc(ps: seq[Palette]) =
      app.palettes = ps
      resolve()

proc fetchBoard(id: Id) =
  apiGetBoard id, proc(b: Board) =
    app.restore b.data
    app.title = b.title
    setPageTitle b.title & " - Board"
    app.loading = false
    redraw()


proc fetchTags(): Future[void] =
  newPromise proc(resolve, reject: proc()) =
    apiGetTagsList proc(tagsList: seq[Tag]) =
      for t in tagsList:
        tags[t.label] = t
      resolve()

proc saveServer =
  let data = forceJsObject toJson app
  proc success =
    notify "saved!"
  apiUpdateBoardContent app.id, data, success


proc zoom(s, Δy: float) =
  let
    ⋊s = exp(-Δy / 400)
    s′ = (s * ⋊s) <> minScale..maxScale
    Δs = s′ - s
    mm = app.stage.center

  if Δs.abs > 0.001:
    changeScale mm, s′, false
    let sw =
      if app.sidebarvisible: app.sidebarWidth
      else: 0
    app.stage.center = mm - v(sw/2, 0) * (1/s - 1/s′)

proc gotoCenterOfBoard =
  let
    s = ||app.stage.scale
    w =
      if app.sidebarVisible: app.sidebarWidth
      else: 0
  app.stage.center = v(0, 0) + v(w/2, 0) * 1/s


proc onPointerDown(e: Event) =
  preventDefault e

  proc movimpl(x, y: int) {.caster.} =
    reconsiderSideBarWidth window.innerWidth - x
    redraw()

  proc movMouse(e: Event as MouseEvent) {.caster.} =
    preventDefault e
    movimpl e.x, e.y

  proc moveTouch(ev: Event as TouchEvent) {.caster.} =
    preventDefault e
    let t = clientPos ev.touches[0]
    movimpl |t.x, |t.y

  proc up =
    winel.removeEventListener "mousemove", movMouse
    winel.removeEventListener "touchmove", moveTouch

  winel.addEventListener "mousemove", movMouse
  winel.addEventListener "touchmove", moveTouch
  winel.addEventListener "mouseup", up
  winel.addEventListener "touchend", up

proc reloadEventListener(e: Element; evt: cstring; act: proc(e: Event)) =
  removeEventListener e, evt, act
  addEventlistener e, evt, act

proc registerHandleEvents =
  let el = ql ".extender-body"
  if el != nil:
    el.reloadEventListener "mousedown", onPointerDown
    el.reloadEventListener "touchstart", onPointerDown


proc sidebarBtn(iconClass, note: string; action: proc()): Vnode =
  buildHtml button(
    class = "btn btn-outline-primary border-0 px-3 py-3",
    onclick = action):
    icon iconClass

    if note != "":
      span(class = "ms-1"):
        text note

proc createDom*(data: RouterData): VNode =
  console.info "just updated the whole virtual DOM"
  let freeze = winel.onmousemove != nil
  registerHandleEvents()

  buildHtml:
    tdiv(class = "karax"):
      main(class = "board-wrapper bg-light overflow-hidden h-100 w-100"):
        verbatimElement "board"

      if app.loading:
        tdiv(class = "position-absolute top-left-center"):
          text "loading..."

      footer(class = "position-absolute bottom-0 left-0 w-100"):
        tdiv(class = "zoom-bar btn-group position-absolute bg-white border border-secondary border-start-0 rounded-right rounded-0"):
          sidebarBtn "fa-minus", "", proc =
            zoom ||app.stage.scale, +zoomStep

          sidebarBtn "fa-plus", "", proc =
            zoom ||app.stage.scale, -zoomStep


        if not app.locked:
          tdiv(class = "inside user-select-none bg-white border-top border-dark-subtle d-flex align-items-center",
                style = style(StyleAttr.width, cstring $iff(
                app.sidebarvisible,
                window.innerWidth - app.sidebarWidth,
                window.innerWidth) & "px")):

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
                font = getFocusedFontFamily()
                theme = getFocusedTheme()

              tdiv(class = "d-inline-flex mx-2 pointer"):
                bold: text "Color: "
                colorSelectBtn(nonExistsTheme, theme, false)

                proc onclick =
                  app.footerState = fsColor

              if app.selectedEdges.len == 0:

                tdiv(class = "d-inline-flex mx-2 pointer"):
                  bold(class = "me-2"): text "Font: "
                  span: text font.family

                  proc onclick =
                    app.footerState = fsFontFamily

                tdiv(class = "d-inline-flex mx-2 pointer"):
                  span: text $font.size

                  proc onclick =
                    app.footerState = fsFontSize

              else:

                tdiv(class = "d-inline-flex mx-2 pointer"):
                  span: text "change direction"

                  proc onclick =
                    changeEdgesDirection app.selectedEdges

              tdiv(class = "d-inline-flex mx-2 pointer"):
                bold: text "connection: "

              tdiv(class = "d-inline-flex mx-2 pointer"):
                span: text $getFocusedConnShape()

                proc onclick =
                  app.footerState = fsBorderShape

              tdiv(class = "d-inline-flex mx-2 pointer"):
                span(class = "me-2"): text "width: "
                span: text $getFocusedEdgeWidth()

                proc onclick =
                  app.footerState = fsBorderWidth

            of fsFontFamily:
              for (fname, _) in fontFamilies:
                fontFamilySelectBtn(fname, true)

            of fsFontSize:
              for s in countup(10, 300, 10):
                fontSizeSelectBtn s, getFocusedFontFamily().size, true, capture(
                    s, proc =
                  setFocusedFontSize s
                  app.footerState = fsOverview)

            of fsBorderWidth:
              for w in countup(10, 100, 5):
                fontSizeSelectBtn w.Tenth, app.edge.width, true, capture(w, proc =
                  setFocusedEdgeWidth w.Tenth
                  app.footerState = fsOverview)

            of fsPalette:
              for i, p in app.palettes:
                span(class = "mx-1 " & iff(i == app.selectedPalleteI, "active"),
                    onclick = genSelectPalette i):
                  text p.name

            of fsColor:
              span(class = "mx-1"):
                text app.palettes[app.selectedPalleteI].name

                proc onclick =
                  app.footerState = fsPalette

              let t = getFocusedTheme()
              for i, ct in app.palettes[app.selectedPalleteI].colorThemes:
                span(class = "mx-1"):
                  colorSelectBtn(t, ct, true)

            of fsBorderShape:
              # let fc = getFocusedConnShape()

              for ct in ConnectionCenterShapeKind:
                span(class = "mx-1", onclick = onclicker(ct)):
                  text $ct

      aside(class = "tool-bar btn-group-vertical position-absolute bg-white border border-secondary border-start-0 rounded-right rounded-0"):
        let
          n = app.selectedVisualNodes.len
          m = app.selectedEdges.len

        if n >= 1 or m >= 1: # if something was selected
          if not app.locked:
            sidebarBtn "fa-trash", "", deleteSelectedNodes
          sidebarBtn "fa-ban", "", proc =
            unselect()
            app.boardstate = bsFree
            # app.state = asNormal

        else:
          let iconName =
            if app.locked: "fa-lock"
            else: "fa-lock-open"

          sidebarBtn iconName, "", toggleLock

        if not app.locked:
          let icn =
            case app.selectMode
            of smSingle: "fa-crosshairs"
            of smAreaNodes: "fa-square-plus"
            of smAreaEdges: "fa-circle-plus"

          sidebarBtn icn, "", changeSelectionMode

        if n > 1:
          sidebarBtn "", $n, noop

        elif n == 1:
          let vn = app.selectedVisualNodes[0]

          if not app.locked:
            sidebarBtn "fa-circle-nodes", "", proc =
              startAddConns [vn]

          sidebarBtn "fa-message", $vn.config.messageIdList.len, proc =
            openSideBar()
            app.sidebarState = ssMessagesView

        else:
          if m == 0 and not app.locked:
            sidebarBtn "fa-plus fa-lg", "", startPuttingNode

          # TODO show shortcut and name via a tooltip
          sidebarBtn "fa-expand fa-lg", "", gotoCenterOfBoard

          if not app.locked:
            sidebarBtn "fa-save fa-lg", "", saveServer

      aside(class = "side-bar position-absolute shadow-sm border bg-white h-100 d-flex flex-row " &
          iff(freeze, "user-select-none ") &
          iff(app.sidebarWidth < ciriticalWidth, "icons-only ") &
          iff(not app.sidebarVisible, "d-none"),
          style = style(
            StyleAttr.width, c fmt"{app.sidebarWidth}px")):

        tdiv(class = "extender h-100 btn btn-light p-0"):
          tdiv(class = "extender-body d-flex rounded-circle justify-content-center align-items-center x-translate-center mt-4 bg-primary text-white"):
            icon "fa-left-right"

        tdiv(class = "d-flex flex-column w-100"):
          header(class = "nav nav-tabs d-flex flex-row justify-content-between align-items-end bg-light mb-2"):

            tdiv(class = "d-flex flex-row"):
              tdiv(class = "nav-item",
                  onclick = sidebarStateMutator ssMessagesView):
                span(class = "nav-link px-3 pointer" &
                    iff(app.sidebarState == ssMessagesView, " active")):
                  span(class = "caption"):
                    text "Messages "
                  icon "fa-message"

              if not app.locked:
                tdiv(class = "nav-item",
                    onclick = sidebarStateMutator ssPropertiesView):
                  span(class = "nav-link px-3 pointer" &
                    iff(app.sidebarState == ssPropertiesView, " active")):

                    if app.selectedVisualNodes.len == 0:
                      span(class = "caption"):
                        text "board "
                      icon "fa-play"

                    else:
                      span(class = "caption"):
                        text "Properties "
                      icon "fa-circle-info"

                tdiv(class = "nav-item",
                    onclick = sidebarStateMutator ssShortcuts):
                  span(class = "nav-link px-3 pointer" &
                    iff(app.sidebarState == ssShortcuts, " active")):
                    span(class = "caption"):
                      text "Shortcuts "
                    icon "fa-keyboard"

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
                  closeSideBar()

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

              else:
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


            of ssShortcuts:
              ul(class = "list-group"):
                for i, sr in app.actionsShortcutRegistery:
                  li(class = "list-group-item d-flex justify-content-between align-items-center"):
                    span(class = "text-muted"):
                      text $i

                    span:
                      if sr.alt:
                        span(class = "badge bg-dark"):
                          text "Alt"
                      if sr.ctrl:
                        span(class = "badge bg-dark"):
                          text "Ctrl"
                      if sr.shift:
                        span(class = "badge bg-dark"):
                          text "Shift"
                      if sr.code notin {kcAlt, kcCtrl, kcShift}:
                        span(class = "badge bg-dark"):
                          text $sr.code

          if
            not app.locked and
            app.sidebarState == ssMessagesView and
            app.selectedVisualNodes.len > 0:

            footer(class = "mt-2"):
              tdiv(class = "input-group"):
                input(`type` = "text", id = "new-message-input",
                    class = "form-control form-control-sm")

                button(class = "input-group-text btn btn-primary"):
                  icon "fa-pen"
                  proc onClick =
                    apiNewNote proc(id: Id) =
                      addToMessages id
                      openNewTab get_note_editor_url(id)

                button(class = "input-group-text btn btn-primary"):
                  icon "fa-add"
                  proc onClick =
                    let
                      inp = el"new-message-input"
                      id = parseInt inp.value
                    addToMessages id
                    inp.value = c""

      snackbar()


proc fitStage(stage: Stage) =
  with stage:
    width = window.innerWidth
    height = window.innerHeight

proc initAreaSelector: KonvaShape =
  result = newRect()
  with result:
    visible = false
    opacity = 0.4
    x = 0
    y = 0
    width = 0
    height = 0
    strokeWidth = 3
    stroke = "blue"
    fill = "skyblue"

proc initCenterPin: KonvaShape =
  result = newCircle()
  with result:
    x = 0
    y = 0
    radius = 2
    stroke = "black"
    strokeWidth = 2


type
  KeyState = enum
    pressed
    released

proc searchShortcut(sc: ShortCut): NOption[ActionKind] =
  for ac, sh in app.actionsShortcutRegistery:
    if sh == sc:
      return some ac

proc takeAction(ac: ActionKind; ks: KeyState) =
  case ks:
  of pressed:
    case ac
    of akDelete:
      deleteSelectedNodes()

    of akCancel:
      case app.boardState
      of bsAddNode:
        destroy app.tempNode.konva.wrapper

      of bsMakeConnection:
        removeTempEdges()

      else:
        discard

      app.boardState = bsFree
      app.footerState = fsOverview
      app.state = asNormal

      unselect()
      redraw()

    of akResetZoom:
      let c = app.stage.center
      changeScale c, 1, false
      app.stage.center = c

    of akFocus:
      if app.selectedVisualNodes.len == 1:
        let v = app.selectedVisualNodes[0]
        app.stage.center = v.center
        app.stage.x = app.stage.x - app.sidebarWidth/2

    of akZoomMode:
      app.zoomKeyHold = true
      setCursor ccZoom

    of akPanMode:
      setCursor ccGrabbing
      app.panKeyHold = true
      app.state = asPan

    of akOpenCloseSidebar:
      if document.activeElement == document.body:
        if app.sidebarVisible: closeSideBar()
        else: openSideBar()
        redraw()

    of akToggleLock:
      negate app.locked
      redraw()

    of akCreateNode:
      startPuttingNode()

    of akCreateConnection:
      startAddConns app.selectedVisualNodes

    of akSave:
      saveServer()

    of akGoCenter:
      gotoCenterOfBoard()

    of akDownload:
      downloadFile "data.json", "application/json",
        stringify forceJsObject toJson app

    of akUpdateScreenShot:
      app.stage.toBlob(1/2).dthen proc(b: Blob) =
        apiUpdateBoardScrenshot app.id, toForm("screenshot.png", b), proc =
          notify "screenshot updated!"

    of akCopyStyle:
      if app.selectedVisualNodes.len == 1:
        let v = app.selectedVisualNodes[0]

        app.theme = v.config.theme
        app.font = v.config.font

      elif app.selectedEdges.len == 1:
        let e = app.selectedEdges[0]

        app.theme = e.data.config.theme
        app.edge = e.data.config

      else:
        notify "nothing to copy style from"

    of akAreaSelectOptions:
      changeSelectionMode()

    else:
      discard

  of released:
    case ac:

    of akZoomMode:
      app.zoomKeyHold = false
      setCursor ccNone

    of akPanMode:
      setCursor ccNone
      app.panKeyHold = false
      app.state = asNormal

    else:
      discard


proc init* =
  add document.body.classList, "overflow-hidden"
  setRenderer createDom
  setTimeout 500, proc =
    let layer = newLayer()

    with app:
      stage = newStage "board"
      hoverGroup = newGroup()
      mainGroup = newGroup()
      bottomGroup = newGroup()
      areaSelectionNode = initAreaSelector()
      # transformer = newTransformer()
      # tempNode: VisualNode

    with app.stage:
      fitStage()

      add layer

      on "touchstart", proc(e: JsObject as KonvaTouchEvent) {.caster.} =
        discard

      on "touchmove", proc(e: JsObject as KonvaTouchEvent) {.caster.} =
        let currentTouches = e.evt.touches
        preventDefault e.evt

        case currentTouches.len
        of 1:
          if app.lastTouches.len == 1: # to prevent unwanted situation
            let
              e = clientPos currentTouches[0]
              r = clientPos app.lastTouches[0]
            moveStage e - r

        of 2: # pinch-zoom
          if app.lastTouches.len == 2: # to prevent unwanted situation
            let
              diff = (distance app.lastTouches) - (distance currentTouches)
              s = ||app.stage.scale
              ⋊s = exp(-diff / 100) <> pinchRatioLimit

            changeScale center currentTouches, s * ⋊s, true

        else:
          discard

        app.lastTouches = currentTouches

      on "touchend", proc =
        reset app.lastTouches

      on "mousedown", proc(ke: JsObject as KonvaMouseEvent) {.caster.} =
        app.leftClicked = true

        if app.selectMode != smSingle:
          let
            m = v(ke.evt.x, ke.evt.y)
            currentMousePos = coordinate(m, app.stage)

          with app.areaSelectionNode:
            visible = true
            position = currentMousePos
            width = 10
            height = 10

      on "mousemove", proc(ke: JsObject as KonvaMouseEvent) {.caster.} =
        let
          m = v(ke.evt.x, ke.evt.y)
          currentMousePos = coordinate(m, app.stage)

        if app.zoomKeyHold:
          let
            s = ||app.stage.scale
            Δy = m.y - app.lastClientMousePos.y
          zoom s, Δy

        elif app.selectMode != smSingle:
          let
            a = app.areaSelectionNode.position
            b = currentMousePos

          app.areaSelectionNode.size = b - a

        elif
          app.panKeyHold or
          app.leftClicked and app.hoverVisualNode.isNone:
          moveStage movement ke

        else:
          case app.boardState
          of bsMakeConnection:
            let v = app.hoverVisualNode

            for i, n1 in app.selectedVisualNodes:
              if ?v:
                let n2 = !v
                updateEdgePos app.tempEdges[i], n1.area, n1.center, n2.area, n2.center
              else:
                let t = newPoint currentMousePos
                updateEdgePos app.tempEdges[i], n1.area, n1.center, t.area, t.position

          of bsAddNode:
            app.tempNode.konva.wrapper.position = currentMousePos
            app.tempNode.config.position = currentMousePos

          else:
            discard

        app.lastAbsoluteMousePos = currentMousePos
        app.lastClientMousePos = m

      on "mouseup", proc =
        let selectedArea = area app.areaSelectionNode

        case app.selectMode
        of smSingle: discard
        of smAreaNodes:
          for _, vn in app.objects:
            if vn.area in selectedArea:
              select vn

          setTimeout 100, proc =
            case app.boardState
            of bsAddNode:
              if app.state == asNormal:
                app.boardState = bsFree
                app.objects[app.tempNode.config.id] = app.tempNode
                app.mainGroup.add app.tempNode.konva.wrapper
                app.tempNode = nil
                # unselect()
            else:
              discard

        of smAreaEdges:
          for _, e in app.edgeInfo:
            if e.konva.shape.area in selectedArea:
              select e

        setTimeout 100, proc =
          case app.boardState
          of bsAddNode:
            if app.state == asNormal:
              app.boardState = bsFree
              app.objects[app.tempNode.config.id] = app.tempNode
              app.mainGroup.add app.tempNode.konva.wrapper
              app.tempNode = nil
              # unselect()
          else:
            discard

        app.leftClicked = false
        app.areaSelectionNode.visible = false
        redraw()

    with app.hoverGroup:
      add app.areaSelectionNode

    with layer:
      add initCenterPin()
      add app.bottomGroup
      add app.mainGroup
      add app.hoverGroup

    block global_events:
      addEventListener window, "resize", proc =
        reconsiderSideBarWidth()
        fitStage app.stage
        redraw()

      addEventListener app.stage.container, "wheel", nonPassive:
        proc (e: Event as WheelEvent) {.caster.} =
          preventDefault e

          let mp = v(e.x, e.y)
          app.lastAbsoluteMousePos = coordinate(mp, app.stage)

          if e.ctrlKey: # pinch-zoom
            let
              s = ||app.stage.scale
              ⋊s = exp(-e.Δy / 100) <>
                  pinchRatioLimit # FIXME this line is common with touch, make it a function

            changeScale mp, s * ⋊s, true

          else: # panning
            moveStage v(e.Δx, e.Δy) * -1

      addEventListener app.stage.container, "contextmenu":
        proc(e: Event) =
          e.preventDefault

      addEventListener document.documentElement, "keydown":
        proc (e: Event as KeyboardEvent) {.caster.} =
          let kc = e.keyCode.KeyCode
          incl app.pressedKeys, kc

          if document.activeElement == document.body:
            if s =? searchShortcut initShortCut e:
              takeAction s, pressed

          else: # if typing in input
            case kc
            of kcEscape:
              blur document.activeElement

            else: discard

      addEventListener document.body, "keyup":
        proc(e: Event as KeyboardEvent) {.caster.} =
          let kc = KeyCode e.keyCode
          app.pressedKeys.excl kc

          if s =? searchShortcut initShortCut e:
            takeAction s, released

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
            add app.mainGroup, vn.konva.wrapper

          elif files.len == 1: # paste by image
            let f = files[0]
            ## TODO change name of image to something with
            ## proper name & extension
            if f.`type`.startswith "image/":
              apiUploadAsset toForm(f.name, f), proc(assetUrl: string) =
                let vn = createNode()

                vn.config.data = VisualNodeData(
                  kind: vndkImage,
                  url: assetUrl)

                loadImageGen assetUrl, vn, true
                add app.mainGroup, vn.konva.wrapper

    block prepare:
      app.sidebarWidth = defaultWidth()
      app.font.family = fontFamilies[1].name
      app.font.size = 20
      app.theme = nonExistsTheme
      app.edge.theme = nonExistsTheme
      app.edge.width = 10.Tenth

    block init:
      moveStage app.stage.center
      redraw()

    app.id = parseInt getWindowQueryParam "id"

    waitAll [
      loadPalettes(),
      loadFonts fontFamilies,
      fetchTags()
    ], proc =
      setFocusedTheme sample (sample app.palettes).colorThemes
      redraw()

      app.loading = true
      fetchBoard app.id


when isMainModule:
  randomize()
  init()
