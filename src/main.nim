import std/[with, dom, jsconsole, lenientops, sugar, jscore, strutils]
from std/jsffi import JsObject

import konva


proc qi(id: string): Element =
  document.getElementById id

proc download(data, memetype: cstring)
  {.importjs: "download(@)".}

proc downloadUrl(name, data: cstring)
  {.importjs: "downloadUrl(@)".}



when isMainModule:
  # --- def ---
  var
    stage = newStage "board"
    layer = newLayer()
    isClicked = false


  # --- functionalities ---

  const scaleStep = 0.25

  proc newScale(⊡: Vector, Δscale: Float) =
    ## ⊡: center

    let
      s = stage.scale.asScalar
      s′ = s + Δscale

      w = stage.width
      h = stage.height

      ⊡′ = ⊡ * s′

    stage.scale = s′
    stage.x = -⊡′.x + w/2
    stage.y = -⊡′.y + h/2

    echo "scale changed: ", s′


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
      s = stage.scale.asScalar

      Δx = ke.evt.deltaX
      Δy = ke.evt.deltaY

      px = ke.evt.clientX
      py = ke.evt.clientY

      sx = stage.x
      sy = stage.y

      h = stage.height
      w = stage.width

      c = stage.center
      gx = (-sx + px)/s
      gy = (-sy + py)/s

    dump (c.x, c.y)
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
      width = 500
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
