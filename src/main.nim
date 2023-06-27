import std/[with, dom, math, options]
from std/jsffi import JsObject
import karax/[karax]
import konva, hotkeys, browser, ui, canvas, utils, conventions


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

func realPos(mousePos: Vector, scale, offsetx, offsety: Float): Vector =
  v(
    (-offsetx + mousePos.x)/scale,
    (-offsety + mousePos.y)/scale)

proc realPos(p: Vector, s: Stage): Vector =
  realPos p, ||s.scale, s.x, s.y

proc center(stage: Stage): Vector =
  ## real coordinate of center of the canvas
  let s = ||app.stage.scale
  v(
    ( -app.stage.x + app.stage.width / 2) / s,
    ( -app.stage.y + app.stage.height / 2) / s)

# --- actions ---

# proc newScale(mouse, real: Vector, Δscale: Float) =
proc newScale(⊡: Vector, Δscale: Float) =
  ## ⊡: center

  let
    s = ||app.stage.scale
    s′ = max(s + Δscale, ⌊scale⌋)

    w = app.stage.width
    h = app.stage.height

    ⊡′ = ⊡ * s′

  app.stage.scale = s′
  app.stage.x = -⊡′.x + w/2
  app.stage.y = -⊡′.y + h/2

proc resetSelected =
  reset app.selectedObject
  app.transformer.nodes = []
  app.transformer.remove

# --- events ---

proc onPasteOnScreen(data: cstring) {.exportc.} =
  newImageFromUrl data, proc(img: Image) =
    with img:
      x = app.lastMousePos.x
      y = app.lastMousePos.y

    img.on "click", proc(ke: JsObject as KonvaClickEvent) {.caster.} =
      stopPropagate ke
      img.draggable = true
      app.transformer.nodes = [KonvaShape img]
      app.layer.batchDraw
      app.selectedObject = some KonvaObject img

    img.on "transformend", proc(ke: JsObject as KonvaClickEvent) {.caster.} =
      img.width = img.width * img.scale.x
      img.height = img.height * img.scale.y
      img.scale = v(1, 1)

    app.layer.add img

proc mouseDownStage(jo: JsObject as KonvaClickEvent) {.caster.} =
  app.isMouseDown = true

proc mouseMoveStage(ke: JsObject as KonvaClickEvent) {.caster.} =
  app.lastMousePos = realPos(v(ke.evt.x, ke.evt.y), app.stage)

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
  app.lastMousePos = realPos(mp, app.stage)

  if e.ctrlKey: # pinch-zoom
    let
      s = ||app.stage.scale
      ⋊s = exp(-e.Δy / 100)


    newScale app.stage.center, s*(⋊s - 1)


  else: # panning
    app.stage.x = app.stage.x + e.Δx * -1
    app.stage.y = app.stage.y + e.Δy * -1


when isMainModule:
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
      add tempCircle(0, 0, 16, "red")
      add tempCircle(0, 0, 1, "black")
      add tempCircle(app.stage.width / 2, 0, 16, "yellow")
      add tempCircle(app.stage.width, 0, 16, "orange")
      add tempCircle(app.stage.width / 2, app.stage.height / 2, 16, "green")
      add tempCircle(app.stage.width, app.stage.height / 2, 16, "purple")
      add tempCircle(app.stage.width / 2, app.stage.height, 16, "pink")
      add tempCircle(0, app.stage.height / 2, 16, "cyan")
      add tempCircle(0, app.stage.height, 16, "khaki")
      add tempCircle(app.stage.width, app.stage.height, 16, "blue")
      add app.transformer


  addHotkey "delete", proc(ev: Event, h: JsObject) =
    app.selectedObject.get.destroy
    app.transformer.nodes = []
