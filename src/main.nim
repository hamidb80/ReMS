import std/[with, dom, math, options]
from std/jsffi import JsObject
import karax/[karax]

import konva, hotkeys, browser
import ui, canvas, utils, conventions


type
  AppData = object
    stage: Stage
    layer: Layer
    # TODO add background layer
    transformer: Transformer
    selectedObject: Option[KonvaObject]
    lastMousePos: Vector
    isMouseDown: bool

# TODO define maximum map [boarders to not go further if not nessesarry]
const ⌊scale⌋ = 0.01 # minimum amount of scale
var app: AppData

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

proc changeScale(mouse🖱️: Vector, Δscale: Float) =
  ## zoom in/out with `real` position pinned
  let

    s = ||app.stage.scale
    s′ = max(s + Δscale, ⌊scale⌋)

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

  app.stage.x = app.stage.x + d.x * s′
  app.stage.y = app.stage.y + d.y * s′

proc moveStage(v: Vector) =
  app.stage.x = app.stage.x + v.x
  app.stage.y = app.stage.y + v.y

proc resetSelected =
  reset app.selectedObject
  app.transformer.nodes = []
  app.transformer.remove

proc incl(t: var Transformer, objs: openArray[KonvaShape], layer: Layer) =
  t.nodes = objs
  layer.add t
  layer.batchDraw

# --- events ---

proc onPasteOnScreen(data: cstring) {.exportc.} =
  newImageFromUrl data, proc(img: Image) =
    with img:
      x = app.lastMousePos.x
      y = app.lastMousePos.y
      strokeWidth = 2
      stroke = "black"
      # setAttr

    img.on "click", proc(ke: JsObject as KonvaClickEvent) {.caster.} =
      stopPropagate ke
      img.draggable = true
      app.selectedObject = some KonvaObject img
      app.transformer.incl [KonvaShape img], app.layer

    img.on "transformend", proc(ke: JsObject as KonvaClickEvent) {.caster.} =
      img.width = img.width * img.scale.x
      img.height = img.height * img.scale.y
      img.scale = v(1, 1)

    app.layer.add img

proc mouseDownStage(jo: JsObject as KonvaClickEvent) {.caster.} =
  app.isMouseDown = true

proc mouseMoveStage(ke: JsObject as KonvaClickEvent) {.caster.} =
  app.lastMousePos = coordinate(v(ke.evt.x, ke.evt.y), app.stage)

proc onStageClick(ke: JsObject as KonvaClickEvent) {.caster.} =
  if issome app.selectedObject:
    app.selectedObject.get.draggable = false
    resetSelected()

  stopPropagate ke

proc mouseUpStage(jo: JsObject as KonvaClickEvent) {.caster.} =
  app.isMouseDown = false

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


when isMainModule:
  echo "compiled at: ", CompileTime

  # --- UI ---
  setRenderer createDom, "app"

  # --- Canvas ---
  500.setTimeout proc =
    with app:
      stage = newStage "board"
      layer = newLayer()
      transformer = newTransformer()

    with app.stage:
      width = window.innerWidth
      height = window.innerHeight
      on "click", onStageClick
      on "mousedown pointerdown", mouseDownStage
      on "mousemove pointermove", mouseMoveStage
      on "mouseup pointerup", mouseUpStage
      add app.layer
    addEventListener app.stage.container, "wheel", onWheel, nonPassive

    with app.layer:
      add tempCircle(0, 0, 8, "black")

    moveStage app.stage.center

  addHotkey "delete", proc(ev: Event, h: JsObject) =
    app.selectedObject.get.destroy
    app.transformer.nodes = []
