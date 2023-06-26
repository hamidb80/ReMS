import std/[with, dom, jsconsole, lenientops, sugar, jscore, strutils, math,
    options]
from std/jsffi import JsObject
include karax/prelude
import konva, hotkeys, browser, view


type
  AppData = object
    stage: Stage
    layer: Layer
    transformer: Transformer
    selectedObject: Option[KonvaObject]
    lastMousePos: Vector
    isMouseDown: bool


when isMainModule:
  # --- def ---
  var app: AppData
  
  # --- UI ---
  setRenderer createDom, "app"

  # --- Init ---
  500.setTimeout proc =
    with app:
      stage = newStage "board"
      layer = newLayer()
      transformer = newTransformer()

    addHotkey "delete", proc(ev: Event, h: JsObject) =
      app.selectedObject.get.destroy
      app.transformer.nodes = []

    # --- functionalities ---

    const
      ⌊scale⌋ = 0.01 # minimum amount of scale

    proc newScale(⊡: Vector, Δscale: Float) =
      ## ⊡: center

      let
        s = app.stage.scale.asScalar
        s′ = max(s + Δscale, ⌊scale⌋)

        w = app.stage.width
        h = app.stage.height

        ⊡′ = ⊡ * s′

      app.stage.scale = s′
      app.stage.x = -⊡′.x + w/2
      app.stage.y = -⊡′.y + h/2

    proc realPos(p: Vector): Vector =
      let
        s = app.stage.scale.asScalar
        sx = app.stage.x
        sy = app.stage.y

        gx = (-sx + p.x)/s
        gy = (-sy + p.y)/s

      v(gx, gy)

    proc onPasteOnScreen(data: cstring) {.exportc.} =
      newImageFromUrl data, proc(img: Image) =
        with img:
          x = app.lastMousePos.x
          y = app.lastMousePos.y

        img.on "click", proc(ke: JsObject as KonvaClickEvent) {.caster.} =
          stopPropagate ke
          img.draggable = true
          app.transformer.nodes = [KonvaShape img]
          app.layer.add app.transformer
          app.layer.batchDraw
          app.selectedObject = some KonvaObject img

        img.on "transformend", proc(ke: JsObject as KonvaClickEvent) {.caster.} =
          img.width = img.width * img.scale.x
          img.height = img.height * img.scale.y
          img.scale = v(1, 1)

        app.layer.add img

    proc cc(x, y, r: Float, f: string): Circle =
      result = newCircle()
      with result:
        x = x
        y = y
        radius = r
        fill = f
        stroke = "black"
        strokeWidth = 2

    # --- events ---
    proc mouseDownStage(jo: JsObject as KonvaClickEvent) {.caster.} =
      app.isMouseDown = true

    proc mouseMoveStage(ke: JsObject as KonvaClickEvent) {.caster.} =
      app.lastMousePos = realPos v(ke.evt.clientx, ke.evt.clienty)

    proc onStageClick(ke: JsObject as KonvaClickEvent) {.caster.} =
      if issome app.selectedObject:
        app.selectedObject.get.draggable = false

      stopPropagate ke
      reset app.selectedObject
      app.transformer.nodes = []
      app.transformer.remove

    proc mouseUpStage(jo: JsObject as KonvaClickEvent) {.caster.} =
      app.isMouseDown = false

    proc center(stage: Stage): Vector =
      ## real coordinate of center of the canvas
      let s = app.stage.scale.asScalar
      v(
        ( -app.stage.x + app.stage.width / 2) / s,
        ( -app.stage.y + app.stage.height / 2) / s,
      )

    proc onWheel(event: Event as WheelEvent) {.caster.} =
      event.preventDefault
      app.lastMousePos = realPos v(event.clientx, event.clienty)

      if event.ctrlKey: # Trackpad pinch-zoom
        let
          s = app.stage.scale.asScalar
          ⋊s = exp(-event.deltaY / 100)

        newScale app.stage.center, s*(⋊s - 1)

      else: # Otherwise, handle trackpad panning
        app.stage.x = app.stage.x + event.deltaX * -1
        app.stage.y = app.stage.y + event.deltaY * -1

    # --- init ---
    with app.stage:
      width = window.innerWidth
      height = window.innerHeight * 0.8

    app.layer.add cc(0, 0, 16, "red")
    app.layer.add cc(0, 0, 1, "black")
    app.layer.add cc(app.stage.width / 2, 0, 16, "yellow")
    app.layer.add cc(app.stage.width, 0, 16, "orange")
    app.layer.add cc(app.stage.width / 2, app.stage.height / 2, 16, "green")
    app.layer.add cc(app.stage.width, app.stage.height / 2, 16, "purple")
    app.layer.add cc(app.stage.width / 2, app.stage.height, 16, "pink")
    app.layer.add cc(0, app.stage.height / 2, 16, "cyan")
    app.layer.add cc(0, app.stage.height, 16, "khaki")
    app.layer.add cc(app.stage.width, app.stage.height, 16, "blue")
    app.stage.add app.layer
    app.stage.on "click", onStageClick
    app.stage.on "mousedown pointerdown", mouseDownStage
    app.stage.on "mousemove pointermove", mouseMoveStage
    app.stage.on "mouseup pointerup", mouseUpStage
    app.stage.container.onNonPassive "wheel", onWheel

