import std/[macros, strformat]
import std/[jsffi, dom]

## TODO publish it as an independent library

type
  KonvaObject* = ref object of JsObject
  KonvaContainer* = ref object of KonvaObject
  KonvaShape* = ref object of KonvaObject

  Stage* = ref object of KonvaContainer
  Layer* = ref object of KonvaContainer
  Group* = ref object of KonvaContainer

  Rect* = ref object of KonvaShape
  Circle* = ref object of KonvaShape
  Image* = ref object of KonvaShape
  # Ellipse = ref object of KonvaShape

  Transformer* = ref object of KonvaContainer

  Vector* = object
    x*, y*: Float

  KonvaEvent*[Event] = ref object of JsObject
    evt*: Event
    cancelBubble*: bool

  WheelEvent* = ref object of MouseEvent
    wheelDelta*: int
    wheelDeltaX*: int
    wheelDeltaY*: int
    which*: int

    deltaMode*: int
    deltaX*: Float
    deltaY*: Float
    deltaZ*: Float

  KonvaMouseEvent* = ref object of KonvaEvent[MouseEvent]
    pointerId*: int

  KonvaClickEvent* = ref object of KonvaMouseEvent

  KonvaCallback* = proc or proc(ke: KonvaEvent)

  Float* = float64
  Str = cstring
  Number = SomeNumber

  KonvaEventKinds = enum
    mouseover, mouseout, mouseenter, mouseleave, mousemove, mousedown, mouseup,
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

func toFloat[F: SomeFloat](f: F): F = f

func v*[N1, N2: SomeNumber](x: N1, y: N2): Vector =
  Vector(x: x.toFloat, y: y.toFloat)

func asScalar*(v: Vector): Float =
  assert v.x == v.y
  v.x

func `+`*(v: Vector, t: Float): Vector =
  v(v.x + t, v.y + t)

func `+`*(v1, v2: Vector): Vector =
  v(v1.x + v2.x, v1.y + v2.y)

func `-`*(v: Vector): Vector =
  v(-v.x, -v.y)

func `-`*(v: Vector, t: Float): Vector =
  v + -t

func `-`*(v1, v2: Vector): Vector =
  v1 + -v2

func `*`*(v: Vector, t: Float): Vector =
  v(v.x * t, v.y * t)

func `/`*(v: Vector, t: Float): Vector =
  v(v.x / t, v.y / t)

# --- utils ---

proc movement*(ke: KonvaMouseEvent): Vector =
  v(ke.evt.movementx.toFloat, ke.evt.movementy.toFloat)

proc stopPropagate*[E](ke: KonvaEvent[E]) =
  ke.cancelBubble = true

proc noOp = discard

# --- constructors ---
proc newStage*(container: Str): Stage {.importjs: "new Konva.Stage({container: #})".}
proc newLayer*: Layer {.importjs: "new Konva.Layer()".}
proc newRect*: Rect {.importjs: "new Konva.Rect()".}
proc newCircle*: Circle {.importjs: "new Konva.Circle()".}
proc newImage*: Image {.importjs: "new Konva.Image()".}
proc newTransformer*: Transformer {.importjs: "new Konva.Transformer()".}
proc newImageFromUrl*(url: Str, onSuccess: proc(img: Image),
    onError = noOp) {.importjs: "Konva.Image.fromURL(@)".}

# --- settings ---
proc toDataURL*(wrapper: KonvaContainer,
    ratio: int): Str {.importjs: "#.toDataURL({ pixelRatio: # })".}
proc draw*(l: Layer) {.konva.}
proc batchDraw*(l: Layer) {.konva.}
proc add*(k, o: KonvaObject) {.konva.}
proc destroy*(k: KonvaObject) {.konva.}
proc remove*(k: KonvaObject) {.konva.}
proc on*[CB: KonvaCallback](k: KonvaObject, event: Str, procedure: CB) {.konva.}
proc `draggable=`*(k: KonvaObject, b: bool) {.konva.}
proc `draggable`*(k: KonvaObject): bool {.konva.}
proc `container=`*(k: Stage, id: Str) {.konva.}
proc `container=`*(k: Stage, element: Element) {.konva.}
proc `container`*(k: Stage): Element {.konva.}
proc `image=`*(k: Image, element: ImageElement) {.konva.}
proc `image`*(k: Image): ImageElement {.konva.}
proc `nodes=`*(t: Transformer, elems: openArray[KonvaShape]) {.konva.}
proc `nodes`*(t: Transformer): seq[KonvaObject] {.konva.}
proc `id=`*(t: Transformer, id: Str) {.konva.}
proc `id`*(t: Transformer): Str {.konva.}
proc `setAttr`*[V](k: KonvaShape, key: string, value: V) {.konva.}
proc `getAttr`*[V](k: KonvaShape, key: string): V {.konva.}
proc `attr`*[V](k: KonvaShape, key: string): V = k.getAttr key

# --- visual properties ---
proc `width=`*[N: Number](k: KonvaObject, v: N) {.konva.}
proc `width`*(k: KonvaObject): Float {.konva.}
proc `height=`*[N: Number](k: KonvaObject, v: N) {.konva.}
proc `height`*(k: KonvaObject): Float {.konva.}
proc `x=`*[N: Number](k: KonvaObject, v: N) {.konva.}
proc `x`*(k: KonvaObject): Float {.konva.}
proc `y=`*[N: Number](k: KonvaObject, v: N) {.konva.}
proc `y`*(k: KonvaObject): Float {.konva.}
proc `fill=`*(k: KonvaObject, color: Str) {.konva.}
proc `fill`*(k: KonvaObject): Str {.konva.}
proc `stroke=`*(k: KonvaShape, color: Str) {.konva.}
proc `stroke`*(k: KonvaShape): Str {.konva.}
proc `strokeWidth=`*[N: Number](k: KonvaShape, v: N) {.konva.}
proc `strokeWidth`*(k: KonvaShape): Float {.konva.}
proc `strokeEnabled=`*(k: KonvaShape, v: bool) {.konva.}
proc `strokeEnabled`*(k: KonvaShape): bool {.konva.}
proc `radius=`*[N: Number](k: KonvaShape, v: N) {.konva.}
proc `radius`*(k: KonvaShape): Float {.konva.}
proc `cornerRadius=`*[N: Number](k: KonvaShape, v: N) {.konva.}
proc `cornerRadius=`*[N: Number](k: KonvaShape, tl, tr, br, bl: N)
    {.importjs: "#.cornerRadius([@])".}
proc `cornerRadius`*(k: KonvaShape): Float {.konva.}
# proc `cornerRadius`*(k: KonvaShape): Float {.konva.} # FIXME it can get array of radiuses ...

proc `shadowBlur=`*[N: Number](k: KonvaShape, v: N) {.konva.}
proc `shadowBlur`*(k: KonvaShape): Float {.konva.}
proc `shadowColor=`*(k: KonvaShape, v: Str) {.konva.}
proc `shadowColor`*(k: KonvaShape): Str {.konva.}
proc `shadowEnabled=`*(k: KonvaShape, v: bool) {.konva.}
proc `shadowEnabled`*(k: KonvaShape): bool {.konva.}
# TODO shadowOffset
proc `shadowOffsetX=`*[N: Number](k: KonvaShape, v: N) {.konva.}
proc `shadowOffsetX`*(k: KonvaShape): Float {.konva.}
proc `shadowOffsetY=`*[N: Number](k: KonvaShape, v: N) {.konva.}
proc `shadowOffsetY`*(k: KonvaShape): Float {.konva.}
proc `shadowOpacity=`*(k: KonvaShape, v: Float) {.konva.}
proc `shadowOpacity`*(k: KonvaShape): Float {.konva.}

# TODO size
# TODO skew
proc `skewX=`*[N: Number](k: KonvaShape, v: N) {.konva.}
proc `skewX`*(k: KonvaShape): Float {.konva.}
proc `skewY=`*[N: Number](k: KonvaShape, v: N) {.konva.}
proc `skewY`*(k: KonvaShape): Float {.konva.}

proc `offsetX=`*[N: Number](k: KonvaShape, v: N) {.konva.}
proc `offsetX`*(k: KonvaShape): Float {.konva.}
proc `offsetY=`*[N: Number](k: KonvaShape, v: N) {.konva.}
proc `offsetY`*(k: KonvaShape): Float {.konva.}

proc `noise=`*(k: KonvaShape, v: Float) {.konva.}
proc `noise`*(k: KonvaShape): Float {.konva.}

proc `scale=`*(k: KonvaObject, v: Vector) {.konva.}
proc `scale=`*[N: Number](k: KonvaObject, v: N) =
  k.scale = v(v.toFloat, v.toFloat)
proc `scale`*(k: KonvaObject): Vector {.konva.}
proc `zIndex=`*(k: KonvaShape, v: int) {.konva.}
proc `zIndex`*(k: KonvaShape): int {.konva.}

proc `name=`*(k: KonvaShape, v: Str) {.konva.}
proc `name`*(k: KonvaShape): Str {.konva.}

# -------- query?
proc hasName*(k: KonvaShape): bool {.konva.}
proc hasFill*(k: KonvaShape): bool {.konva.}
proc hasShadow*(k: KonvaShape): bool {.konva.}
proc hasStroke*(k: KonvaShape): bool {.konva.}
proc isCached*(k: KonvaShape): bool {.konva.}
proc isDragging*(k: KonvaShape): bool {.konva.}
proc isListening*(k: KonvaShape): bool {.konva.}
proc isVisible*(k: KonvaShape): bool {.konva.}

# -------- actions
proc addName*(k: KonvaShape, name: Str) {.konva.}
proc show*(k: KonvaShape) {.konva.}
proc hide*(k: KonvaShape) {.konva.}
proc off*(k: KonvaShape, eventSrc: Str) {.konva.}
proc startDrag*(k: KonvaShape) {.konva.}
proc stopDrag*(k: KonvaShape) {.konva.}
proc clearCache*(k: KonvaShape) {.konva.}
proc moveDown*(k: KonvaShape) {.konva.}
proc moveToBottom*(k: KonvaShape) {.konva.}
proc moveUp*(k: KonvaShape) {.konva.}
proc moveToTop*(k: KonvaShape) {.konva.}
