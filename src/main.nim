import std/[with, dom, jsconsole, lenientops, sugar, jscore, strutils]
from std/jsffi import JsObject

import konva, browser



when isMainModule:
  # --- def ---
  var
    stage = newStage "board"
    layer = newLayer()
    lastPos = v(0, 0)
    isClicked = false


  # --- functionalities ---

  const 
    scaleStep = 0.25
    minScale = 0.1

  proc newScale(⊡: Vector, Δscale: Float) =
    ## ⊡: center

    let
      s = max(stage.scale.asScalar, minScale)
      s′ = s + Δscale

      w = stage.width
      h = stage.height

      ⊡′ = ⊡ * s′

    stage.scale = s′
    stage.x = -⊡′.x + w/2
    stage.y = -⊡′.y + h/2

    echo "scale changed: ", s′

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
      layer.add img
      console.log img

  # --- events ---
  proc clickkk(ke: JsObject as KonvaClickEvent) {.caster.} =
    echo ke is KonvaEvent
    # stopPropagate ke

  proc mouseDownStage(jo: JsObject as KonvaClickEvent) {.caster.} =
    isClicked = true

  proc mouseMoveStage(ke: JsObject as KonvaClickEvent) {.caster.} =
    if isClicked:
      let m = ke.movement
      stage.x = stage.x + m.x
      stage.y = stage.y + m.y

    lastPos = realPos v(ke.evt.clientx, ke.evt.clienty)

  proc mouseUpStage(jo: JsObject as KonvaClickEvent) {.caster.} =
    isClicked = false


  # proc ontouchstart(jo: JsObject as KonvaClickEvent) {.caster.} =
  # proc ontouchmove(ke: JsObject as KonvaClickEvent) {.caster.} =
  # proc ontouchend(jo: JsObject as KonvaClickEvent) {.caster.} =

  proc onpointerdown(jo: JsObject as KonvaClickEvent) {.caster.} =
    echo "👇"

  proc onpointermove(ke: JsObject as KonvaClickEvent) {.caster.} =
    # echo "👋"
    discard

  proc onpointereup(jo: JsObject as KonvaClickEvent) {.caster.} =
    echo "👆"


  proc center(stage: Stage): Vector =
    ## real coordinate of center of the canvas
    let s = stage.scale.asScalar
    v(
      ( -stage.x + stage.width / 2) / s,
      ( -stage.y + stage.height / 2) / s,
    )

  proc onWheel(ke: JsObject as KonvaEvent[WheelEvent]) {.caster.} =
    ke.evt.preventdefault

    let
      Δy = ke.evt.deltaY
      h = stage.height
      c = stage.center

    newScale c, Δy * 2 / h

  proc cc(x, y, r: Float, f: string): Circle =
    result = newCircle()
    with result:
      x = x
      y = y
      radius = r
      fill = f
      stroke = "black"
      strokeWidth = 2


  # --- init ---
  block canvas:
    with stage:
      width = window.innerWidth
      height = 500
      add layer

    let circle = cc(0, 0, 16, "red")

    layer.add circle
    layer.add cc(0, 0, 1, "black")
    layer.add cc(stage.width / 2, 0, 16, "yellow")
    layer.add cc(stage.width, 0, 16, "orange")
    layer.add cc(stage.width / 2, stage.height / 2, 16, "green")
    layer.add cc(stage.width, stage.height / 2, 16, "purple")
    layer.add cc(stage.width / 2, stage.height, 16, "pink")
    layer.add cc(0, stage.height / 2, 16, "cyan")
    layer.add cc(0, stage.height, 16, "khaki")
    layer.add cc(stage.width, stage.height, 16, "blue")

    circle.on "click", clickkk
    stage.on "mousedown", mouseDownStage
    stage.on "mousemove", mouseMoveStage
    stage.on "mouseup", mouseUpStage
    stage.on "pointerdown", onpointerdown
    stage.on "pointermove", onpointermove
    stage.on "pointerup", onpointereup
    stage.on "wheel", onWheel


  block UI:

    proc report =
      let c = stage.center
      console.log "----------------"
      dump stage.scale.asScalar
      dump (stage.x, stage.y)
      dump (c.x, c.y)

    "zoom+".qi.onclick = proc(e: Event) =
      newScale stage.center, +scaleStep

    "zoom-".qi.onclick = proc(e: Event) =
      newScale stage.center, -scaleStep

    "action!".qi.onclick = proc(e: Event) =
      echo "nothing"

    "report".qi.onclick = proc(e: Event) =
      report()
