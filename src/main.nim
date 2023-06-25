import std/[with, jsffi, jsconsole]
import konva


proc clickkk(jo: JsObject as KonvaClickEvent) {.caster.} =
  echo jo.pointerId
  echo "wow"


when isMainModule:
  var
    stage = newStage "board"
    layer = newLayer()
    circle = newCircle()

  with stage:
    width = 500
    height = 500

  with circle:
    x = stage.width / 2
    y = stage.height / 2
    radius = 70
    fill = "red"
    stroke = "black"
    strokeWidth = 4

  layer.add circle
  stage.add layer
  layer.draw

  circle.on "click", clickkk
