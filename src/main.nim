import std/[with, jsffi, dom, jsconsole, lenientops, sugar]
import konva


proc qi(id: string): Element =
  document.getElementById id


when isMainModule:
  # --- def ---
  var
    stage = newStage "board"
    layer = newLayer()
    isClicked = false

  # --- events ---
  proc clickkk(ke: JsObject as KonvaClickEvent) {.caster.} =
    ke.cancelBubble = true


  proc mouseDownStage(jo: JsObject as KonvaClickEvent) {.caster.} =
    isClicked = true

  proc mouseMoveStage(ke: JsObject as KonvaClickEvent) {.caster.} =
    if isClicked:
      let m = ke.movement
      stage.x = stage.x + m.x
      stage.y = stage.y + m.y

  proc mouseUpStage(jo: JsObject as KonvaClickEvent) {.caster.} =
    isClicked = false

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
    stage.add layer
    layer.draw

    circle.on "click", clickkk
    stage.on "mousedown", mouseDownStage
    stage.on "mousemove", mouseMoveStage
    stage.on "mouseup", mouseUpStage


  block UI:
    const scaleStep = 0.5

    proc center(stage: Stage): Vector =
      ## real coordinate of center of the canvas
      v(
        ( -stage.x + stage.width / 2) / stage.scale.asScalar,
        ( -stage.y + stage.height / 2) / stage.scale.asScalar,
      )

    proc newScale(⊡: Vector, Δscale: Float) =
      ## ⊡: center

      let
        w = stage.width
        h = stage.height
        w₂ = w/2
        h₂ = h/2

        s = stage.scale.asScalar
        x = stage.x
        y = stage.y

        s′ = s + Δscale
        x′ = w₂ # ⊡.x
        y′ = h₂ # ⊡.y

      stage.scale = s′
      stage.x = x′
      stage.y = y′
      
      console.log "----------------"
      dump s′
      dump w / s′
      dump x′
      dump y′


    "zoom+".qi.onclick = proc(e: Event) =
      newScale stage.center, +scaleStep

    "zoom-".qi.onclick = proc(e: Event) =
      newScale stage.center, -scaleStep

    "action!".qi.onclick = proc(e: Event) =
      newScale v(0,0), 0

    proc report =
      console.log "----------------"
      dump stage.x
      dump stage.y
      dump stage.scale.asScalar

    "report".qi.onclick = proc(e: Event) =
      report()
