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
    mouseover, mouseout, mouseenter, mouseleave, mousemove, mousedown, mouseup, wheel, click, dblclick # Mouse events
    touchstart, touchmove, touchend, tap, dbltap # Touch events
    pointerdown, pointermove, pointereup, pointercancel, pointerover, pointerenter, pointerout,pointerleave, pointerclick, pointerdblclick # Pointer events
    dragstart, dragmove, dragend # Drag events
    transformstart, transform, transformend # Transform events


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
proc newImageFromUrl*(url: Str, onSuccess: proc(img: Image), onError = noOp) {.importjs: "Konva.Image.fromURL(@)".}

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
proc `radius=`*[N: Number](k: KonvaShape, v: N) {.konva.}
proc `radius`*(k: KonvaShape): Float {.konva.}
proc `scale=`*(k: KonvaObject, v: Vector) {.konva.}
proc `scale=`*[N: Number](k: KonvaObject, v: N) =
  k.scale = v(v.toFloat, v.toFloat)
proc `scale`*(k: KonvaObject): Vector {.konva.}
