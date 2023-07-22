import std/[macros, strformat]
import std/[jsffi, dom]

## TODO publish it as an independent library

type
  Vector* = object
    x*, y*: Float

  Size* = object
    width*, height*: Float

  RectData* = object
    x*, y*, width*, height*: Float

  Float* = float64
  Str = cstring
  Number = SomeNumber

  Probablity = range[0.0 .. +1.0]
  UnitAxis = range[-1.0 .. +1.0]
  ImaginaryPercent = range[-100.0 .. +100.0]
  ColorChannel = range[0 .. 255]
  Degree = range[0.0 .. 360.0]


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
    deltaX*: Float
    deltaY*: Float
    deltaZ*: Float

  KonvaMouseEvent* = ref object of KonvaEvent[MouseEvent]
    pointerId*: int

  KonvaClickEvent* = ref object of KonvaMouseEvent

  KonvaCallback* = proc(ke: JsObject)

type
  FontVariant* = enum
    fvVormal = "normal"
    fvSmallCaps = "small-caps"

  LineCap* = enum
    lcButt = "butt"
    lcRound = "round"
    lcSquare = "square"

  LineJoin* = enum
    ljMiter = "miter"
    ljRound = "round"
    ljBevel = "bevel"

  TransformsOption* = enum
    toAll = "all"
    toNone = "none"
    toPosition = "position"

  VerticalAlign* = enum
    vaTop = "top"
    vaMiddle = "middle"
    vaBottom = "bottom"

  HorizontalAlign* = enum
    hzLeft = "left"
    hzCenter = "center"
    hzRight = "right"

  WrapOption* = enum
    woWord = "word"
    woChar = "char"
    woNone = "none"

  FontStyle* = enum
    fsNormal = "normal"
    fsBold = "bold"
    fsItalic = "italic"
    fsItalicBold = "italic bold"

  TextDecoration* = enum
    tdNothing = ""
    tdLineThrough = "line-through"
    tdUnderline = "underline"

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

# ---------- constructors
proc newStage*(container: Str): Stage {.importjs: "new Konva.Stage({container: #})".}
proc newLayer*: Layer {.importjs: "new Konva.Layer()".}
proc newRect*: Rect {.importjs: "new Konva.Rect()".}
proc newCircle*: Circle {.importjs: "new Konva.Circle()".}
proc newImage*: Image {.importjs: "new Konva.Image()".}
proc newText*: Text {.importjs: "new Konva.Text()".}
proc newTransformer*: Transformer {.importjs: "new Konva.Transformer()".}
proc newImageFromUrl*(url: Str, onSuccess: proc(img: Image),
    onError = noOp) {.importjs: "Konva.Image.fromURL(@)".}

# ---------- getter/setter
proc `x=`*[N: Number](k: KonvaObject, v: N) {.konva.}
proc `x`*(k: KonvaObject): Float {.konva.}
proc `y=`*[N: Number](k: KonvaObject, v: N) {.konva.}
proc `y`*(k: KonvaObject): Float {.konva.}
proc `absolutePosition=`*(k: KonvaObject, v: Vector) {.konva.}
proc `absolutePosition`*(k: KonvaObject): Vector {.konva.}
proc `position=`*(k: KonvaObject, v: Vector) {.konva.}
proc `position`*(k: KonvaObject): Vector {.konva.}

proc `width=`*[N: Number](k: KonvaObject, v: N) {.konva.}
proc `width`*(k: KonvaObject): Float {.konva.}
proc `height=`*[N: Number](k: KonvaObject, v: N) {.konva.}
proc `height`*(k: KonvaObject): Float {.konva.}
proc `size=`*(k: KonvaObject, v: Size) {.konva.}
proc `size`*(k: KonvaObject): Size {.konva.}

proc `fill=`*(k: KonvaObject, color: Str) {.konva.}
proc `fill`*(k: KonvaObject): Str {.konva.}
proc `dash=`*[N: Number](k: KonvaObject, dashArray: openArray[N]) {.konva.}
proc `dash`*(k: KonvaObject): openArray[Float] {.konva.}
proc `dashEnabled=`*(k: KonvaObject, v: bool) {.konva.}
proc `dashEnabled`*(k: KonvaObject): bool {.konva.}
proc `stroke=`*(k: KonvaObject, color: Str) {.konva.}
proc `stroke`*(k: KonvaObject): Str {.konva.}
proc `strokeWidth=`*[N: Number](k: KonvaObject, v: N) {.konva.}
proc `strokeWidth`*(k: KonvaObject): Float {.konva.}
proc `strokeEnabled=`*(k: KonvaObject, v: bool) {.konva.}
proc `strokeEnabled`*(k: KonvaObject): bool {.konva.}
proc `radius=`*[N: Number](k: KonvaShape, v: N) {.konva.}
proc `radius`*(k: KonvaShape): Float {.konva.}
proc `cornerRadius=`*[N: Number](k: KonvaShape, v: N) {.konva.}
proc `cornerRadius=`*[N: Number](k: KonvaShape, tl, tr, br, bl: N)
    {.importjs: "#.cornerRadius([@])".}
proc `cornerRadius`*(k: KonvaShape): JsObject {.konva.}
proc `perfectDrawEnabled=`*(t: KonvaShape, v: bool) {.konva.}
proc `perfectDrawEnabled`*(t: KonvaShape): bool {.konva.}

proc `shadowBlur=`*[N: Number](k: KonvaObject, v: N) {.konva.}
proc `shadowBlur`*(k: KonvaObject): Float {.konva.}
proc `shadowColor=`*(k: KonvaObject, v: Str) {.konva.}
proc `shadowColor`*(k: KonvaObject): Str {.konva.}
proc `shadowEnabled=`*(k: KonvaObject, v: bool) {.konva.}
proc `shadowEnabled`*(k: KonvaObject): bool {.konva.}
proc `shadowOffset=`*(k: KonvaObject, v: Vector) {.konva.}
proc `shadowOffset`*(k: KonvaObject): Vector {.konva.}
proc `shadowOffsetX=`*[N: Number](k: KonvaObject, v: N) {.konva.}
proc `shadowOffsetX`*(k: KonvaObject): Float {.konva.}
proc `shadowOffsetY=`*[N: Number](k: KonvaObject, v: N) {.konva.}
proc `shadowOffsetY`*(k: KonvaObject): Float {.konva.}
proc `shadowOpacity=`*(k: KonvaObject, v: Float) {.konva.}
proc `shadowOpacity`*(k: KonvaObject): Float {.konva.}

proc `alpha=`*(k: KonvaObject, v: Probablity) {.konva.}
proc `alpha`*(k: KonvaObject): Probablity {.konva.}
proc `red=`*(k: KonvaObject, v: ColorChannel) {.konva.}
proc `red`*(k: KonvaObject): ColorChannel {.konva.}
proc `green=`*(k: KonvaObject, v: ColorChannel) {.konva.}
proc `green`*(k: KonvaObject): ColorChannel {.konva.}
proc `blue=`*(k: KonvaObject, v: ColorChannel) {.konva.}
proc `blue`*(k: KonvaObject): ColorChannel {.konva.}

proc `skew=`*(k: KonvaObject, v: Vector) {.konva.}
proc `skew`*(k: KonvaObject): Vector {.konva.}
proc `skewX=`*[N: Number](k: KonvaObject, v: N) {.konva.}
proc `skewX`*(k: KonvaObject): Float {.konva.}
proc `skewY=`*[N: Number](k: KonvaObject, v: N) {.konva.}
proc `skewY`*(k: KonvaObject): Float {.konva.}

proc `offsetX=`*[N: Number](k: KonvaObject, v: N) {.konva.}
proc `offsetX`*(k: KonvaObject): Float {.konva.}
proc `offsetY=`*[N: Number](k: KonvaObject, v: N) {.konva.}
proc `offsetY`*(k: KonvaObject): Float {.konva.}

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

proc `nodes=`*(t: KonvaContainer, elems: openArray[KonvaShape]) {.konva.}
proc `nodes`*(t: KonvaContainer): seq[KonvaObject] {.konva.}

proc `id=`*(t: KonvaShape, id: Str) {.konva.}
proc `id`*(t: KonvaShape): Str {.konva.}
proc `setAttr`*[V](k: KonvaShape, key: string, value: V) {.konva.}
proc `getAttr`*[V](k: KonvaShape, key: string): V {.konva.}
proc `attr`*[V](k: KonvaShape, key: string): V = k.getAttr key

proc `visible=`*(t: KonvaShape, v: bool) {.konva.}
proc `visible`*(t: KonvaShape): bool {.konva.}
proc `listening=`*(t: KonvaShape, v: bool) {.konva.}
proc `listening`*(t: KonvaShape): bool {.konva.}
proc `value=`*(t: KonvaShape, v: Float) {.konva.}
proc `value`*(t: KonvaShape): Float {.konva.}

# TODO filters(filters) getter/setter
proc `brightness=`*(t: KonvaShape, v: UnitAxis) {.konva.}
proc `brightness`*(t: KonvaShape): UnitAxis {.konva.}
proc `hue=`*(t: KonvaShape, v: Degree) {.konva.}
proc `hue`*(t: KonvaShape): Degree {.konva.}
proc `contrast=`*(t: KonvaShape, v: ImaginaryPercent) {.konva.}
proc `contrast`*(t: KonvaShape): ImaginaryPercent {.konva.}
proc `saturation=`*(t: KonvaShape, v: Float) {.konva.}
proc `saturation`*(t: KonvaShape): Float {.konva.}
proc `enhance=`*(t: KonvaShape, v: UnitAxis) {.konva.}
proc `enhance`*(t: KonvaShape): UnitAxis {.konva.}
proc `pixelSize=`*(t: KonvaShape, v: Natural) {.konva.}
proc `pixelSize`*(t: KonvaShape): Natural {.konva.}
proc `embossBlend=`*(t: KonvaShape, v: bool) {.konva.}
proc `embossBlend`*(t: KonvaShape): bool {.konva.}
proc `kaleidoscopePower=`*(t: KonvaShape, v: int) {.konva.}
proc `kaleidoscopePower`*(t: KonvaShape): int {.konva.}
proc `kaleidoscopeAngle=`*(t: KonvaShape, v: int) {.konva.}
proc `kaleidoscopeAngle`*(t: KonvaShape): int {.konva.}
proc `noise=`*(k: KonvaShape, v: Float) {.konva.}
proc `noise`*(k: KonvaShape): Float {.konva.}
proc `threshold=`*(t: KonvaShape, v: Probablity) {.konva.}
proc `threshold`*(t: KonvaShape): Probablity {.konva.}

proc `text=`*(t: KonvaShape, v: Str) {.konva.}
proc `text`*(t: KonvaShape): Str {.konva.}
proc `textDecoration=`*(t: KonvaShape, v: Str) {.konva.}
proc `textDecoration`*(t: KonvaShape): Str {.konva.}
proc `letterSpacing=`*[N: Number](k: KonvaObject, v: N) {.konva.}
proc `letterSpacing`*(k: KonvaObject): Float {.konva.}
proc `ellipsis=`*(t: KonvaShape, v: bool) {.konva.}
proc `ellipsis`*(t: KonvaShape): bool {.konva.}

proc `fontVariant=`*(t: KonvaShape, v: Str) {.konva.}
proc `fontVariant`*(t: KonvaShape): Str {.konva.}
proc `fontFamily=`*(t: KonvaShape, v: Str) {.konva.}
proc `fontFamily`*(t: KonvaShape): Str {.konva.}
proc `fontStyle=`*(t: KonvaShape, v: Str) {.konva.}
proc `fontStyle`*(t: KonvaShape): Str {.konva.}
proc `fontSize=`*[N: Number](t: KonvaShape, v: N) {.konva.}
proc `fontSize`*(t: KonvaShape): Float {.konva.}
proc measureSize*(t: KonvaShape, s: Str): Size {.konva.}
proc measureSize*(t: KonvaShape): Size {.konva.}

proc `lineHeight=`*[N: Number](k: KonvaObject, v: N) {.konva.}
proc `lineHeight`*(k: KonvaObject): Float {.konva.}
proc `lineCap=`*(k: KonvaObject, mode: Str) {.konva.}
proc `lineCap`*(k: KonvaObject): Str {.konva.}
proc `lineJoin=`*(k: KonvaObject, mode: Str) {.konva.}
proc `lineJoin`*(k: KonvaObject): Str {.konva.}

proc `align=`*(t: KonvaShape, v: Str) {.konva.}
proc `align`*(t: KonvaShape): Str {.konva.}
proc `verticalAlign=`*(t: KonvaShape, v: Str) {.konva.}
proc `verticalAlign`*(t: KonvaShape): Str {.konva.}
proc `wrap=`*(t: KonvaShape, v: Str) {.konva.}
proc `wrap`*(t: KonvaShape): Str {.konva.}

proc `padding=`*[N: Number](t: KonvaShape, v: N) {.konva.}
proc `padding`*(t: KonvaShape): Float {.konva.}

proc `rotation=`*[N: Number](t: KonvaShape, v: N) {.konva.}
proc `rotation`*(t: KonvaShape): Float {.konva.}
proc `levels=`*(t: KonvaShape, v: Float) {.konva.}
proc `levels`*(t: KonvaShape): Float {.konva.}

# -------- query?
proc hasName*(k: KonvaShape): bool {.konva.}
proc hasFill*(k: KonvaShape): bool {.konva.}
proc hasShadow*(k: KonvaShape): bool {.konva.}
proc hasStroke*(k: KonvaShape): bool {.konva.}
proc isCached*(k: KonvaShape): bool {.konva.}
proc isDragging*(k: KonvaShape): bool {.konva.}
proc isListening*(k: KonvaShape): bool {.konva.}
proc isVisible*(k: KonvaShape): bool {.konva.}
proc isClientRectOnScreen*(k: KonvaShape): bool {.konva.}
proc isClientRectOnScreen*(k: KonvaShape, v: Vector): bool {.konva.}
proc intersects*(k: KonvaShape, v: Vector): bool {.konva.}

# -------- getter
proc getAbsoluteOpacity*(k: KonvaShape): Float {.konva.}
proc getAbsoluteRotation*(k: KonvaShape): Float {.konva.}
proc getAbsoluteScale*(k: KonvaShape): Vector {.konva.}
proc getAbsoluteTransform*(k: KonvaShape): Transformer {.konva.}
proc getAbsoluteZIndex*(k: KonvaObject): Natural {.konva.}
proc getAbsolutePosition*(k: KonvaObject): Vector {.konva.}
proc getAbsolutePosition*(k: KonvaObject, o: KonvaObject): Vector {.konva.}
proc getClassName*(k: KonvaObject): Str {.konva.}
proc getClientRect*(k: KonvaObject): RectData {.konva.}
proc getSelfRect*(k: KonvaObject): Vector {.konva.}
proc getRelativePointerPosition*(k: KonvaObject): Vector {.konva.}
proc getDepth*(k: KonvaObject): Natural {.konva.}
proc getLayer*(k: KonvaShape): Layer {.konva.}
proc getParent*(k: KonvaShape): KonvaObject {.konva.}
proc getStage*(k: KonvaShape): Stage {.konva.}
proc getTextWidth*(k: Text): Float {.konva.}
proc getAncestors*(k: KonvaObject): seq[KonvaObject] {.konva.}
# findAncestors

# -------- actions
proc on*(k: KonvaObject, event: Str, procedure: KonvaCallback) {.konva.}
proc off*(k: KonvaObject, event: Str) {.konva.}
proc fire*(k: KonvaObject, event: Str, data: JsObject = nil,
    bubles = true) {.konva.}

proc addName*(k: KonvaShape, name: Str) {.konva.}
proc removeName*(k: KonvaShape, name: Str) {.konva.}
proc clearCache*(k: KonvaShape) {.konva.}

proc startDrag*(k: KonvaShape) {.konva.}
proc stopDrag*(k: KonvaShape) {.konva.}

proc rotate*[N: Number](k: KonvaShape, deg: N) {.konva.}

proc show*(k: KonvaShape) {.konva.}
proc hide*(k: KonvaShape) {.konva.}

proc move(k: KonvaShape, v: Vector) {.konva.}
proc moveDown*(k: KonvaShape) {.konva.}
proc moveToBottom*(k: KonvaShape) {.konva.}
proc moveUp*(k: KonvaShape) {.konva.}
proc moveToTop*(k: KonvaShape) {.konva.}

proc draw*(l: Layer) {.konva.}
proc batchDraw*(l: Layer) {.konva.}

proc add*(k, o: KonvaObject) {.konva.}
proc destroy*(k: KonvaObject) {.konva.}
proc remove*(k: KonvaObject) {.konva.}

proc preventDefault*(k: KonvaObject) {.konva.}
proc clone*(k: KonvaObject): KonvaObject {.konva.}

proc toDataURL*(wrapper: KonvaContainer, ratio: int): Str
  {.importjs: "#.toDataURL({ pixelRatio: # })".}
