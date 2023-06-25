import std/[macros, strformat]
import std/[jsffi, dom]
import macroplus

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
  # Ellipse = ref object of KonvaShape


  KonvaEvent* = ref object of JsObject

  Vector* = ref object of JsObject
    x*, y*: Float

  KonvaMouseEvent* = ref object of KonvaEvent
    pointerId*: int
    evt*: MouseEvent
    # `type`*: Str

  KonvaClickEvent* = ref object of KonvaMouseEvent

  KonvaCallback* = proc or proc(ke: KonvaEvent)

  Float = float64
  Str = cstring
  Number = SomeNumber


proc toKonvaMethod(def: NimNode): NimNode =
  result = def
  result.addPragma newColonExpr(ident"importjs", newLit fmt"#.{def.name}(@)")

macro konva(def): untyped =
  ## adds `importjs` pragma automatically
  toKonvaMethod def

macro caster*(def): untyped =
  ## support for cast in args,
  ##
  ## for example below procedure
  ## should treat `ev` as an `KonvaClickEvent` rather `JsObject`
  ## it is specially useful in event handling scenarios.
  ##
  ## proc callback(ev: JsObject as KonvaClickEvent) {.caster.} = ...

  var before = newStmtList()
  result = def

  for i, p in def.params:
    if i != 0: # return type
      for id in p[IdentDefNames]:
        let t = p[IdentDefType]
        if t.matchInfix "as":
          before.add newLetStmt(id, newTree(nnkCast, t[InfixRightSide], id))
          result.params[i][IdentDefType] = t[InfixLeftSide]

  result.body = newStmtList(before, result.body)

# --- utils ---

func `+`*(v: Vector, t: Float): Vector = 
  Vector(x: v.x + t, y: v.y + t)

func `-`*(v: Vector, t: Float): Vector = 
  v + -t

func `*`*(v: Vector, t: Float): Vector = 
  Vector(x: v.x * t, y: v.y * t)

# --- constructors ---
proc newStage*(container: Str): Stage {.importjs: "new Konva.Stage({container: #})".}
proc newLayer*: Layer {.importjs: "new Konva.Layer()".}
proc newRect*: Rect {.importjs: "new Konva.Rect()".}
proc newCircle*: Circle {.importjs: "new Konva.Circle()".}

# --- settings ---
proc draw*(l: Layer) {.konva.}
proc add*(k, o: KonvaObject) {.konva.}
proc on*[CB: KonvaCallback](k: KonvaObject, event: Str, procedure: CB) {.konva.}

proc `scale=`*(k: KonvaObject, v: Vector) {.konva.}
proc `scale=`*[N: Number](k: KonvaObject, v: N) =
  k.scale = Vector(x: v.toFloat, y: v.toFloat)

proc `scale`*(k: KonvaObject): Vector {.konva.}
proc `draggable=`*(k: KonvaObject, b: bool) {.konva.}
proc `draggable`*(k: KonvaObject): bool {.konva.}
proc `container=`*(k: Stage, id: Str) {.konva.}
proc `container=`*(k: Stage, element: Element) {.konva.}
proc `container`*(k: Stage): Element {.konva.}

# --- visual properties ---
proc `fill=`*(k: KonvaShape, color: Str) {.konva.}
proc `fill`*(k: KonvaShape): Str {.konva.}
proc `stroke=`*(k: KonvaShape, color: Str) {.konva.}
proc `stroke`*(k: KonvaShape): Str {.konva.}
proc `width=`*[N: Number](k: KonvaObject, v: N) {.konva.}
proc `width`*(k: KonvaObject): Float {.konva.}
proc `height=`*[N: Number](k: KonvaObject, v: N) {.konva.}
proc `height`*(k: KonvaObject): Float {.konva.}
proc `strokeWidth=`*[N: Number](k: KonvaShape, v: N) {.konva.}
proc `strokeWidth`*(k: KonvaShape): Float {.konva.}
proc `radius=`*[N: Number](k: KonvaShape, v: N) {.konva.}
proc `radius`*(k: KonvaShape): Float {.konva.}
proc `x=`*[N: Number](k: KonvaShape, v: N) {.konva.}
proc `x`*(k: KonvaShape): Float {.konva.}
proc `y=`*[N: Number](k: KonvaShape, v: N) {.konva.}
proc `y`*(k: KonvaShape): Float {.konva.}
