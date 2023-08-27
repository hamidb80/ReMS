import std/[macros, strformat]
import std/[jsffi, dom, asyncjs]
import prettyvec


type
  Vector* = Vec2Obj

  Size* = object
    width*, height*: float

  RectData* = object
    x*, y*, width*, height*: float

  Area* = object
    x1*, x2*, y1*, y2*: float

  Str = cstring
  Number = SomeNumber

  Probablity = range[0.0 .. +1.0]
  UnitAxis = range[-1.0 .. +1.0]
  ImaginaryPercent = range[-100.0 .. +100.0]
  ColorChannel = range[0 .. 255]
  Degree = range[0.0 .. 360.0]


type
  KonvaObject* = ref object of JsRoot
  KonvaContainer* = ref object of KonvaObject
  KonvaShape* = ref object of KonvaObject

  Stage* = ref object of KonvaContainer
  Layer* = ref object of KonvaContainer
  Group* = ref object of KonvaContainer

  Line* = ref object of KonvaShape
  Path* = ref object of KonvaShape
  Rect* = ref object of KonvaShape
  Circle* = ref object of KonvaShape
  Image* = ref object of KonvaShape
  Ellipse* = ref object of KonvaShape
  Text* = ref object of KonvaShape
  Transformer* = ref object of KonvaContainer

type
  KonvaEvent*[Event] = ref object of JsObject
    evt*: Event
    cancelBubble*: bool

  WheelEvent* = ref object of MouseEvent
    wheelDelta*: int
    wheelDeltaX*: int
    wheelDeltaY*: int
    which*: int

    deltaMode*: int
    deltaX*: float
    deltaY*: float
    deltaZ*: float

  KonvaMouseEvent* = ref object of KonvaEvent[MouseEvent]
    pointerId*: int

  KonvakeyboardEvent* = ref object of KonvaEvent[KeyboardEvent]

  KonvaCallback* = proc(ke: JsObject)

  KonvaEventKind* = enum
    mouseover, mouseout, mouseenter, mouseleave,
    mousemove, mousedown, mouseup,
        wheel, click, dblclick                           # Mouse events
    touchstart, touchmove, touchend, tap, dbltap         # Touch events
    pointerdown, pointermove, pointereup, pointercancel, pointerover,
        pointerenter, pointerout, pointerleave, pointerclick, pointerdblclick # Pointer events
    dragstart, dragmove, dragend                         # Drag events
    transformstart, transform, transformend              # Transform events


proc toKonvaMethod(def: NimNode): NimNode =
  result = def
  result.addPragma newColonExpr(ident"importjs", newLit fmt"#.{def.name}(@)")

macro konva(def): untyped =
  ## adds `importjs` pragma automatically
  toKonvaMethod def

# --- types ---

func toFloat[F: Somefloat](f: F): F = f

func v*[N1, N2: SomeNumber](x: N1, y: N2): Vector =
  Vector(x: x.toFloat, y: y.toFloat)

func asScalar*(v: Vector): float =
  assert v.x == v.y, $v
  v.x

func v*(s: Size): Vector =
  v(s.width, s.height)

# --- utils ---

proc noOp = discard

proc movement*(ke: KonvaMouseEvent): Vector =
  v(ke.evt.movementx.toFloat, ke.evt.movementy.toFloat)

proc stopPropagate*[E](ke: KonvaEvent[E]) =
  ke.cancelBubble = true

func spreadPoints*(vs: openArray[Vector]): seq[float] =
  for v in vs:
    result.add v.x
    result.add v.y

func foldPoints*(s: openArray[float]): seq[Vector] =
  assert s.len mod 2 == 0
  for i in countup(0, s.high, 2):
    result.add v(s[i], s[i+1])

# ---------- constructors
proc newStage*(container: Str): Stage {.importjs: "new Konva.Stage({container: #})".}
proc newLayer*: Layer {.importjs: "new Konva.Layer()".}
proc newLine*: Line {.importjs: "new Konva.Line()".}
proc newPath*: Path {.importjs: "new Konva.Path()".}
proc newRect*: Rect {.importjs: "new Konva.Rect()".}
proc newCircle*: Circle {.importjs: "new Konva.Circle()".}
proc newImage*: Image {.importjs: "new Konva.Image()".}
proc newText*: Text {.importjs: "new Konva.Text()".}
proc newGroup*: Group {.importjs: "new Konva.Group()".}
proc newTransformer*: Transformer {.importjs: "new Konva.Transformer()".}
proc newImageFromUrl*(url: Str, onSuccess: proc(img: Image),
    onError = noOp) {.importjs: "Konva.Image.fromURL(@)".}

# ---------- getter/setter
proc `x=`*[N: Number](k: KonvaObject, v: N) {.konva.}
proc `x`*(k: KonvaObject): float {.konva.}
proc `y=`*[N: Number](k: KonvaObject, v: N) {.konva.}
proc `y`*(k: KonvaObject): float {.konva.}
proc `absolutePosition=`*(k: KonvaObject, v: Vector) {.konva.}
proc `absolutePosition`*(k: KonvaObject): Vector {.konva.}
proc `position=`*(k: KonvaObject, v: Vector) {.konva.}
proc `position`*(k: KonvaObject): Vector {.konva.}

proc `width=`*[N: Number](k: KonvaObject, v: N) {.konva.}
proc `width`*(k: KonvaObject): float {.konva.}
proc `height=`*[N: Number](k: KonvaObject, v: N) {.konva.}
proc `height`*(k: KonvaObject): float {.konva.}
proc `size=`*(k: KonvaObject, v: Size) {.konva.}
proc `size`*(k: KonvaObject): Size {.konva.}

proc `data=`*(k: KonvaObject, v: cstring) {.konva.}
proc `data`*(k: KonvaObject): cstring {.konva.}
proc `points=`*[N: SomeNumber](k: KonvaObject, v: openArray[N]) {.konva.}
proc `points=`*(k: KonvaObject, v: openArray[
    Vector]) = k.points = v.spreadPoints
proc `points`*(k: KonvaObject): seq[float] {.konva.}

proc `fill=`*(k: KonvaObject, color: Str) {.konva.}
proc `fill`*(k: KonvaObject): Str {.konva.}
proc `fillEnabled=`*(k: KonvaObject, v: bool) {.konva.}
proc `fillEnabled`*(k: KonvaObject): bool {.konva.}
proc `dash=`*[N: Number](k: KonvaObject, dashArray: openArray[N]) {.konva.}
proc `dash`*(k: KonvaObject): openArray[float] {.konva.}
proc `dashEnabled=`*(k: KonvaObject, v: bool) {.konva.}
proc `dashEnabled`*(k: KonvaObject): bool {.konva.}
proc `stroke=`*(k: KonvaObject, color: Str) {.konva.}
proc `stroke`*(k: KonvaObject): Str {.konva.}
proc `strokeWidth=`*[N: Number](k: KonvaObject, v: N) {.konva.}
proc `strokeWidth`*(k: KonvaObject): float {.konva.}
proc `strokeEnabled=`*(k: KonvaObject, v: bool) {.konva.}
proc `strokeEnabled`*(k: KonvaObject): bool {.konva.}
proc `radius=`*[N: Number](k: KonvaObject, v: N) {.konva.}
proc `radius`*(k: KonvaObject): float {.konva.}
proc `cornerRadius=`*[N: Number](k: KonvaObject, v: N) {.konva.}
proc `cornerRadius=`*[N: Number](k: KonvaObject, tl, tr, br, bl: N)
    {.importjs: "#.cornerRadius([@])".}
proc `cornerRadius`*(k: KonvaObject): JsObject {.konva.}
proc `perfectDrawEnabled=`*(t: KonvaObject, v: bool) {.konva.}
proc `perfectDrawEnabled`*(t: KonvaObject): bool {.konva.}

proc `shadowBlur=`*[N: Number](k: KonvaObject, v: N) {.konva.}
proc `shadowBlur`*(k: KonvaObject): float {.konva.}
proc `shadowColor=`*(k: KonvaObject, v: Str) {.konva.}
proc `shadowColor`*(k: KonvaObject): Str {.konva.}
proc `shadowEnabled=`*(k: KonvaObject, v: bool) {.konva.}
proc `shadowEnabled`*(k: KonvaObject): bool {.konva.}
proc `shadowForStrokeEnabled=`*(k: KonvaObject, v: bool) {.konva.}
proc `shadowForStrokeEnabled`*(k: KonvaObject): bool {.konva.}
proc `shadowOffset=`*(k: KonvaObject, v: Vector) {.konva.}
proc `shadowOffset`*(k: KonvaObject): Vector {.konva.}
proc `shadowOffsetX=`*[N: Number](k: KonvaObject, v: N) {.konva.}
proc `shadowOffsetX`*(k: KonvaObject): float {.konva.}
proc `shadowOffsetY=`*[N: Number](k: KonvaObject, v: N) {.konva.}
proc `shadowOffsetY`*(k: KonvaObject): float {.konva.}
proc `shadowOpacity=`*(k: KonvaObject, v: float) {.konva.}
proc `shadowOpacity`*(k: KonvaObject): float {.konva.}

proc `opacity=`*(k: KonvaObject, v: float) {.konva.}
proc `opacity`*(k: KonvaObject): float {.konva.}
proc `alpha=`*(k: KonvaObject, v: Probablity) {.konva.}
proc `alpha`*(k: KonvaObject): Probablity {.konva.}
proc `red=`*(k: KonvaObject, v: ColorChannel) {.konva.}
proc `red`*(k: KonvaObject): ColorChannel {.konva.}
proc `green=`*(k: KonvaObject, v: ColorChannel) {.konva.}
proc `green`*(k: KonvaObject): ColorChannel {.konva.}
proc `blue=`*(k: KonvaObject, v: ColorChannel) {.konva.}
proc `blue`*(k: KonvaObject): ColorChannel {.konva.}

proc `clip=`*(k: KonvaObject, v: RectData) {.konva.}
proc `clip`*(k: KonvaObject): RectData {.konva.}
proc `clipX=`*[N: Number](k: KonvaObject, v: N) {.konva.}
proc `clipX`*(k: KonvaObject): float {.konva.}
proc `clipY=`*[N: Number](k: KonvaObject, v: N) {.konva.}
proc `clipY`*(k: KonvaObject): float {.konva.}
proc `clipWidth=`*[N: Number](k: KonvaObject, v: N) {.konva.}
proc `clipWidth`*(k: KonvaObject): float {.konva.}
proc `clipHeight=`*[N: Number](k: KonvaObject, v: N) {.konva.}
proc `clipHeight`*(k: KonvaObject): float {.konva.}

proc `skew=`*(k: KonvaObject, v: Vector) {.konva.}
proc `skew`*(k: KonvaObject): Vector {.konva.}
proc `skewX=`*[N: Number](k: KonvaObject, v: N) {.konva.}
proc `skewX`*(k: KonvaObject): float {.konva.}
proc `skewY=`*[N: Number](k: KonvaObject, v: N) {.konva.}
proc `skewY`*(k: KonvaObject): float {.konva.}

proc `offsetX=`*[N: Number](k: KonvaObject, v: N) {.konva.}
proc `offsetX`*(k: KonvaObject): float {.konva.}
proc `offsetY=`*[N: Number](k: KonvaObject, v: N) {.konva.}
proc `offsetY`*(k: KonvaObject): float {.konva.}

proc `scale=`*(k: KonvaObject, v: Vector) {.konva.}
proc `scale=`*[N: Number](k: KonvaObject, v: N) =
  k.scale = v(v.toFloat, v.toFloat)
proc `scale`*(k: KonvaObject): Vector {.konva.}

proc `zIndex=`*(k: KonvaObject, v: int) {.konva.}
proc `zIndex`*(k: KonvaObject): int {.konva.}

proc `name=`*(k: KonvaObject, v: Str) {.konva.}
proc `name`*(k: KonvaObject): Str {.konva.}

proc `draggable=`*(k: KonvaObject, b: bool) {.konva.}
proc `draggable`*(k: KonvaObject): bool {.konva.}

proc `container=`*(k: Stage, id: Str) {.konva.}
proc `container=`*(k: Stage, element: Element) {.konva.}
proc `container`*(k: Stage): Element {.konva.}
proc `image=`*(k: Image, element: ImageElement) {.konva.}
proc `image`*(k: Image): ImageElement {.konva.}

# TODO findAncestors
proc findOne*(k: KonvaObject, selector: Str): KonvaObject {.konva.}
proc find1*(k: KonvaObject, selector: Str): KonvaObject = k.findOne selector
proc find*(k: KonvaObject, selector: Str): seq[KonvaObject] {.konva.}
proc getChildren*(k: KonvaObject, filter: proc(k: KonvaObject): bool):
  seq[KonvaObject] {.konva.}
proc getChildren*(k: KonvaObject): seq[KonvaObject] {.konva.}

proc `nodes=`*(t: KonvaContainer, elems: openArray[KonvaObject]) {.konva.}
proc `nodes`*(t: KonvaContainer): seq[KonvaObject] {.konva.}

proc `id=`*(t: KonvaObject, id: Str) {.konva.}
proc `id`*(t: KonvaObject): Str {.konva.}
proc `setAttr`*[V](k: KonvaObject, key: string, value: V) {.konva.}
proc `getAttr`*[V](k: KonvaObject, key: string): V {.konva.}
proc `attrs`*(k: KonvaObject): JsObject {.importjs: "#.attrs".}
proc `attr`*[V](k: KonvaObject, key: string): V = k.getAttr key

proc `visible=`*(t: KonvaObject, v: bool) {.konva.}
proc `visible`*(t: KonvaObject): bool {.konva.}
proc `listening=`*(t: KonvaObject, v: bool) {.konva.}
proc `listening`*(t: KonvaObject): bool {.konva.}
proc `value=`*(t: KonvaObject, v: float) {.konva.}
proc `value`*(t: KonvaObject): float {.konva.}

# TODO filters(filters) getter/setter
proc `brightness=`*(t: KonvaObject, v: UnitAxis) {.konva.}
proc `brightness`*(t: KonvaObject): UnitAxis {.konva.}
proc `hue=`*(t: KonvaObject, v: Degree) {.konva.}
proc `hue`*(t: KonvaObject): Degree {.konva.}
proc `contrast=`*(t: KonvaObject, v: ImaginaryPercent) {.konva.}
proc `contrast`*(t: KonvaObject): ImaginaryPercent {.konva.}
proc `saturation=`*(t: KonvaObject, v: float) {.konva.}
proc `saturation`*(t: KonvaObject): float {.konva.}
proc `enhance=`*(t: KonvaObject, v: UnitAxis) {.konva.}
proc `enhance`*(t: KonvaObject): UnitAxis {.konva.}
proc `pixelSize=`*(t: KonvaObject, v: Natural) {.konva.}
proc `pixelSize`*(t: KonvaObject): Natural {.konva.}
proc `embossBlend=`*(t: KonvaObject, v: bool) {.konva.}
proc `embossBlend`*(t: KonvaObject): bool {.konva.}
proc `kaleidoscopePower=`*(t: KonvaObject, v: int) {.konva.}
proc `kaleidoscopePower`*(t: KonvaObject): int {.konva.}
proc `kaleidoscopeAngle=`*(t: KonvaObject, v: int) {.konva.}
proc `kaleidoscopeAngle`*(t: KonvaObject): int {.konva.}
proc `noise=`*(k: KonvaObject, v: float) {.konva.}
proc `noise`*(k: KonvaObject): float {.konva.}
proc `threshold=`*(t: KonvaObject, v: Probablity) {.konva.}
proc `threshold`*(t: KonvaObject): Probablity {.konva.}

proc `text=`*(t: KonvaObject, v: Str) {.konva.}
proc `text`*(t: KonvaObject): Str {.konva.}
proc `textDecoration=`*(t: KonvaObject, v: Str) {.konva.}
proc `textDecoration`*(t: KonvaObject): Str {.konva.}
proc `letterSpacing=`*[N: Number](k: KonvaObject, v: N) {.konva.}
proc `letterSpacing`*(k: KonvaObject): float {.konva.}
proc `ellipsis=`*(t: KonvaObject, v: bool) {.konva.}
proc `ellipsis`*(t: KonvaObject): bool {.konva.}

proc `fontVariant=`*(t: KonvaObject, v: Str) {.konva.}
proc `fontVariant`*(t: KonvaObject): Str {.konva.}
proc `fontFamily=`*(t: KonvaObject, v: Str) {.konva.}
proc `fontFamily`*(t: KonvaObject): Str {.konva.}
proc `fontStyle=`*(t: KonvaObject, v: Str) {.konva.}
proc `fontStyle`*(t: KonvaObject): Str {.konva.}
proc `fontSize=`*[N: Number](t: KonvaObject, v: N) {.konva.}
proc `fontSize`*(t: KonvaObject): float {.konva.}
proc measureSize*(t: KonvaObject, s: Str): Size {.konva.}
proc measureSize*(t: KonvaObject): Size {.konva.}

proc `lineHeight=`*[N: Number](k: KonvaObject, v: N) {.konva.}
proc `lineHeight`*(k: KonvaObject): float {.konva.}
proc `lineCap=`*(k: KonvaObject, mode: Str) {.konva.}
proc `lineCap`*(k: KonvaObject): Str {.konva.}
proc `lineJoin=`*(k: KonvaObject, mode: Str) {.konva.}
proc `lineJoin`*(k: KonvaObject): Str {.konva.}

proc `align=`*(t: KonvaObject, v: Str) {.konva.}
proc `align`*(t: KonvaObject): Str {.konva.}
proc `verticalAlign=`*(t: KonvaObject, v: Str) {.konva.}
proc `verticalAlign`*(t: KonvaObject): Str {.konva.}
proc `wrap=`*(t: KonvaObject, v: Str) {.konva.}
proc `wrap`*(t: KonvaObject): Str {.konva.}

proc `padding=`*[N: Number](t: KonvaObject, v: N) {.konva.}
proc `padding`*(t: KonvaObject): float {.konva.}

proc `src=`*(t: KonvaObject, v: Str) {.importjs: "#.src = #".}
proc `src`*(t: KonvaObject): Str {.importjs: "#.src".}

proc `rotation=`*[N: Number](t: KonvaObject, v: N) {.konva.}
proc `rotation`*(t: KonvaObject): float {.konva.}
proc `levels=`*(t: KonvaObject, v: float) {.konva.}
proc `levels`*(t: KonvaObject): float {.konva.}

proc `transformsEnabled=`*(t: KonvaObject, v: Str) {.konva.}
proc `transformsEnabled`*(t: KonvaObject): Str {.konva.}

# -------- query?
proc hasName*(k: KonvaObject): bool {.konva.}
proc hasFill*(k: KonvaObject): bool {.konva.}
proc hasShadow*(k: KonvaObject): bool {.konva.}
proc hasStroke*(k: KonvaObject): bool {.konva.}
proc isCached*(k: KonvaObject): bool {.konva.}
proc isDragging*(k: KonvaObject): bool {.konva.}
proc isListening*(k: KonvaObject): bool {.konva.}
proc isVisible*(k: KonvaObject): bool {.konva.}
proc isClientRectOnScreen*(k: KonvaObject): bool {.konva.}
proc isClientRectOnScreen*(k: KonvaObject, v: Vector): bool {.konva.}
proc intersects*(k: KonvaObject, v: Vector): bool {.konva.}

# -------- getter
proc getAbsoluteOpacity*(k: KonvaObject): float {.konva.}
proc getAbsoluteRotation*(k: KonvaObject): float {.konva.}
proc getAbsoluteScale*(k: KonvaObject): Vector {.konva.}
proc getAbsoluteTransform*(k: KonvaObject): Transformer {.konva.}
proc getAbsoluteZIndex*(k: KonvaObject): Natural {.konva.}
proc getAbsolutePosition*(k: KonvaObject): Vector {.konva.}
proc getAbsolutePosition*(k: KonvaObject, o: KonvaObject): Vector {.konva.}
proc getClassName*(k: KonvaObject): Str {.konva.}
proc getClientRect*(k: KonvaObject): RectData {.konva.}
proc getSelfRect*(k: KonvaObject): Vector {.konva.}
proc getRelativePointerPosition*(k: KonvaObject): Vector {.konva.}
proc getDepth*(k: KonvaObject): Natural {.konva.}
proc getLayer*(k: KonvaObject): Layer {.konva.}
proc getParent*(k: KonvaObject): KonvaObject {.konva.}
proc getStage*(k: KonvaObject): Stage {.konva.}
proc getTextWidth*(k: Text): float {.konva.}
proc getAncestors*(k: KonvaObject): seq[KonvaObject] {.konva.}
proc getIntersection*(s: Stage, pos: Vector): KonvaObject {.konva.}
proc getAllIntersections*(k: KonvaContainer, pos: Vector): seq[
    KonvaObject] {.konva.}

# -------- actions
proc removeChildren*(k: KonvaObject) {.konva.}

proc on*(k: KonvaObject, event: Str, procedure: KonvaCallback) {.konva.}
proc on*(k: KonvaObject, event: Str, procedure: proc()) {.konva.}
proc off*(k: KonvaObject, event: Str) {.konva.}
proc fire*(k: KonvaObject, event: Str, data: JsObject = nil,
    bubles = true) {.konva.}

proc addName*(k: KonvaObject, name: Str) {.konva.}
proc removeName*(k: KonvaObject, name: Str) {.konva.}
proc clearCache*(k: KonvaObject) {.konva.}
proc cache*(k: KonvaObject) {.konva.}

proc startDrag*(k: KonvaObject) {.konva.}
proc stopDrag*(k: KonvaObject) {.konva.}

proc rotate*[N: Number](k: KonvaObject, deg: N) {.konva.}

proc show*(k: KonvaObject) {.konva.}
proc hide*(k: KonvaObject) {.konva.}

proc move(k: KonvaObject, v: Vector) {.konva.}
proc moveDown*(k: KonvaObject) {.konva.}
proc moveToBottom*(k: KonvaObject) {.konva.}
proc moveUp*(k: KonvaObject) {.konva.}
proc moveToTop*(k: KonvaObject) {.konva.}

proc draw*(l: Layer or Stage) {.konva.}
proc batchDraw*(l: Layer or Stage) {.konva.}

proc add*(k, o: KonvaObject) {.konva.}
proc destroy*(k: KonvaObject) {.konva.}
proc remove*(k: KonvaObject) {.konva.}

proc preventDefault*(k: KonvaObject) {.konva.}
proc clone*(k: KonvaObject, options: JsObject = jsUndefined): KonvaObject {.konva.}

proc toJSON*(k: KonvaObject) {.konva.}
proc toObject*(k: KonvaObject) {.konva.}
proc toDataURL*(wrapper: KonvaObject, ratio: SomeNumber): Str
  {.importjs: "#.toDataURL({ pixelRatio: # })".}
proc toBlob*(wrapper: KonvaContainer, ratio: SomeNumber): Future[Blob]
  {.importjs: "#.toBlob({ pixelRatio: #})".}

# --------- Helper

func `-`*(a: Vector): Vector = v(-a.x, -a.y)
func area*(k: KonvaObject): Area =
  let
    p = k.position
    s = k.size

  Area(
    x1: p.x,
    x2: p.x + s.width,
    y1: p.y,
    y2: p.y + s.height)

func topLeft*(a: Area): Vector = v(a.x1, a.y1)
func topRight*(a: Area): Vector = v(a.x2, a.y1)
func bottomLeft*(a: Area): Vector = v(a.x1, a.y2)
func bottomRight*(a: Area): Vector = v(a.x2, a.y2)
func center*(a: Area): Vector = v(a.x1+a.x2, a.y1+a.y2) / 2
func `+`*(a: Area, v: Vector): Area =
  Area(
    x1: a.x1+v.x,
    x2: a.x2+v.x,
    y1: a.y1+v.y,
    y2: a.y2+v.y)

func center*(k: KonvaObject): Vector =
  k.position + v(k.size) / 2

func contains*(a: Area, v: Vector): bool =
  v.x in a.x1..a.x2 and
  v.y in a.y1..a.y2
