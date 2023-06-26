import std/[with, dom, jsconsole, lenientops, sugar, jscore, strutils, math, options]
from std/jsffi import JsObject

import konva, browser, hotkeys



when isMainModule:
  # --- def ---
  var
    objCounter = 0
    stage = newStage "board"
    layer = newLayer()
    tr = newTransformer()
    lastPos = v(0, 0)
    selectedObject: Option[KonvaObject]
    isClicked = false

  addHotkey "delete", proc(ev: Event, h: JsObject) =
    selectedObject.get.destroy
    tr.nodes = []

  # --- functionalities ---

  const
    ⌊scale⌋ = 0.01 # minimum amount of scale

  proc newScale(⊡: Vector, Δscale: Float) =
    ## ⊡: center

    let
      s = stage.scale.asScalar
      s′ = max(s + Δscale, ⌊scale⌋)

      w = stage.width
      h = stage.height

      ⊡′ = ⊡ * s′

    stage.scale = s′
    stage.x = -⊡′.x + w/2
    stage.y = -⊡′.y + h/2

  proc realPos(p: Vector): Vector =
    let
      s = stage.scale.asScalar

      sx = stage.x
      sy = stage.y

      gx = (-sx + p.x)/s
      gy = (-sy + p.y)/s

    v(gx, gy)

  proc onPasteOnScreen(data: cstring) {.exportc.} =
    newImageFromUrl data, proc(img: Image) =
      let c = objCounter

      with img:
        x = lastPos.x
        y = lastPos.y

      img.on "click", proc(ke: JsObject as KonvaClickEvent) {.caster.} =
        stopPropagate ke
        img.draggable = true
        tr.nodes = [KonvaShape img]
        layer.add tr
        layer.batchDraw
        selectedObject = some KonvaObject img

      img.on "transformend", proc(ke: JsObject as KonvaClickEvent) {.caster.} =
        img.width = img.width * img.scale.x
        img.height = img.height * img.scale.y
        img.scale = v(1, 1)



      layer.add img
      inc objCounter

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
    isClicked = true

  proc mouseMoveStage(ke: JsObject as KonvaClickEvent) {.caster.} =
    lastPos = realPos v(ke.evt.clientx, ke.evt.clienty)

  proc clickkk(ke: JsObject as KonvaClickEvent) {.caster.} =
    stopPropagate ke
    reset selectedObject
    tr.nodes = []
    tr.remove

    if ke.evt.ctrlKey:
      let i = objCounter
      let pos = realPos v(ke.evt.clientX, ke.evt.clientY)
      let c = cc(pos.x, pos.y, 16, "black")

      c.on "click", proc =
        echo i

      layer.add c
      objCounter.inc

  proc mouseUpStage(jo: JsObject as KonvaClickEvent) {.caster.} =
    isClicked = false

  proc center(stage: Stage): Vector =
    ## real coordinate of center of the canvas
    let s = stage.scale.asScalar
    v(
      ( -stage.x + stage.width / 2) / s,
      ( -stage.y + stage.height / 2) / s,
    )

  proc onWheel(event: Event as WheelEvent) {.caster.} =
    event.preventDefault
    lastPos = realPos v(event.clientx, event.clienty)

    if event.ctrlKey: # Trackpad pinch-zoom
      let
        s = stage.scale.asScalar
        ⋊s = exp(-event.deltaY / 100)

      newScale stage.center, s*(⋊s - 1)

    else: # Otherwise, handle trackpad panning
      stage.x = stage.x + event.deltaX * -1
      stage.y = stage.y + event.deltaY * -1


  # --- init ---
  block canvas:
    with stage:
      width = window.innerWidth
      height = window.innerHeight * 0.8
      add layer

    layer.add cc(0, 0, 16, "red")
    layer.add cc(0, 0, 1, "black")
    layer.add cc(stage.width / 2, 0, 16, "yellow")
    layer.add cc(stage.width, 0, 16, "orange")
    layer.add cc(stage.width / 2, stage.height / 2, 16, "green")
    layer.add cc(stage.width, stage.height / 2, 16, "purple")
    layer.add cc(stage.width / 2, stage.height, 16, "pink")
    layer.add cc(0, stage.height / 2, 16, "cyan")
    layer.add cc(0, stage.height, 16, "khaki")
    layer.add cc(stage.width, stage.height, 16, "blue")

    stage.on "click", clickkk
    stage.on "mousedown pointerdown", mouseDownStage
    stage.on "mousemove pointermove", mouseMoveStage
    stage.on "mouseup pointerup", mouseUpStage
    stage.container.onNonPassive "wheel", onWheel


  block UI:
    "action!".qi.onclick = proc(e: Event) =
      echo "nothing"

    "save".qi.onclick = proc(e: Event) =
      downloadUrl "result.png", stage.toDataURL 2
