import std/[with, dom, jsconsole, lenientops, sugar, jscore, strutils, math]
from std/jsffi import JsObject

import konva, browser



when isMainModule:
  # --- def ---
  var
    objCounter = 0
    stage = newStage "board"
    layer = newLayer()
    tr = newTransformer()
    lastPos = v(0, 0)
    isClicked = false


  # --- functionalities ---

  const
    scaleStep = 0.25
    ⌊scale⌋ = 0.1 # minimum amount of scale

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
        echo "hey!!"
        img.draggable = true
        tr.nodes  @[KonvaShape img]
        layer.add tr
        layer.batchDraw

      layer.add img
      inc objCounter


  # --- events ---

  proc cc(x, y, r: Float, f: string): Circle =
    result = newCircle()
    with result:
      x = x
      y = y
      radius = r
      fill = f
      stroke = "black"
      strokeWidth = 2

  proc clickkk(ke: JsObject as KonvaClickEvent) {.caster.} =
    stopPropagate ke

    if ke.evt.ctrlKey:
      let i = objCounter
      let pos = realPos v(ke.evt.clientX, ke.evt.clientY)
      let c = cc(pos.x, pos.y, 16, "black")
   
      c.on "click", proc =
        echo i

      layer.add c
      objCounter.inc


  proc mouseDownStage(jo: JsObject as KonvaClickEvent) {.caster.} =
    isClicked = true

  proc mouseMoveStage(ke: JsObject as KonvaClickEvent) {.caster.} =
    lastPos = realPos v(ke.evt.clientx, ke.evt.clienty)

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

    # Trackpad pinch-zoom
    if event.ctrlKey:
      let
        s = stage.scale.asScalar
        ⋊s = exp(-event.deltaY / 100)

      newScale stage.center, s*(⋊s - 1)

    # Otherwise, handle trackpad panning
    else:
      let dir =
        if true: -1 # `natural.checked` natrual is a check box: -1
        else: 1

      # Apply to target state
      stage.x = stage.x + event.deltaX * dir
      stage.y = stage.y + event.deltaY * dir


  # --- init ---
  block canvas:
    with stage:
      width = window.innerWidth
      height = 500
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
    "zoom+".qi.onclick = proc(e: Event) =
      newScale stage.center, +scaleStep

    "zoom-".qi.onclick = proc(e: Event) =
      newScale stage.center, -scaleStep

    "action!".qi.onclick = proc(e: Event) =
      echo "nothing"
