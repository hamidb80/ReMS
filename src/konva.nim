import std/[macros, strformat, strutils]
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

  KonvaMouseEvent* = ref object of KonvaEvent
    pointerId*: int

  KonvaClickEvent* = ref object of KonvaMouseEvent


  KonvaCallback* = proc or proc(ke: KonvaEvent)

  Float = float64
  Str = cstring
  Number = SomeNumber


func realParamCount(params: NimNode): int =
  ## to support grouped args (a, b: int)
  for p in params:
    result.inc max(0, p.len - 2)

proc toKonvaMethod(def: NimNode): NimNode =
  result = def

  let
    name = def.name
    argsLen = pred realParamCount def.params
    args = repeat("#, ", argsLen).strip(chars = {' ', ','})
    pragma = newColonExpr(ident"importjs", newLit fmt"#.{name}({args})")

  result.addPragma pragma

macro konva(def): untyped =
  ## adds `importjs` pragma automatically
  toKonvaMethod def

macro caster*(def): untyped =
  ## support for cast in args, for example below procedure
  ## should treat `ev` as an `KonvaClickEvent` rather `JsObject`
  ## it is specially usefull in event handling scenarios.
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

# --- constructors ---
proc newStage*(container: Str): Stage {.importjs: "new Konva.Stage({container: #})".}
proc newLayer*: Layer {.importjs: "new Konva.Layer()".}
proc newRect*: Rect {.importjs: "new Konva.Rect()".}
proc newCircle*: Circle {.importjs: "new Konva.Circle()".}

# --- settings ---
proc draw*(l: Layer) {.konva.}
proc add*(k, o: KonvaObject) {.konva.}
proc on*[CB: KonvaCallback](k: KonvaObject, event: Str, procedure: CB) {.konva.}

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
