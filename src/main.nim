import std/[with, jsffi, dom, jsconsole, lenientops, sugar, jsffi, jscore, strutils]
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


  block UI:
    const scaleStep = 0.4

    proc center(stage: Stage): Vector =
      ## real coordinate of center of the canvas
      let s = stage.scale.asScalar
      v(
        ( -stage.x + stage.width / 2) / s,
        ( -stage.y + stage.height / 2) / s,
      )

    proc report =
      let c = stage.center
      console.log "----------------"
      dump stage.scale.asScalar
      dump (stage.x, stage.y)
      dump (c.x, c.y)

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


    "zoom+".qi.onclick = proc(e: Event) =
      newScale stage.center, +scaleStep

    "zoom-".qi.onclick = proc(e: Event) =
      newScale stage.center, -scaleStep

    "action!".qi.onclick = proc(e: Event) =
      echo "nothing"

    "report".qi.onclick = proc(e: Event) =
      report()


  when false:
    when p == 250:
      1/2 -> 125
      1 -> 0
      3/2 -> -125
      2 -> -250
      5/2 -> -375
      3 -> -500
      7/2 -> -625
      4 -> -750

    elif p == 500:
      1/2 -> 0
      1 -> -250
      3/2 -> -500
      2 -> -750
      5/2 -> -1000
      3 -> -1250
      7/2 -> -1500
      4 -> -1750

    elif p == 0:
      1/2 -> +250
      1 -> +250
      3/2 -> +250
      2 -> +250
      5/2 -> +250
      3 -> +250
      7/2 -> +250
      4 -> +250


    fn0 (p: 0, s):
      250 + s * p

    fn1 (p: 250, s):
      (s - 1.0) * p

    fn2 (p: 500, s):
      (s - 0.5) * p
