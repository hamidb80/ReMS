import std/[with, jsffi, dom, jsconsole]
import konva


proc clickkk(jo: JsObject as KonvaClickEvent) {.caster.} =
  console.log jo
  echo "wow"

proc panIn(jo: JsObject as KonvaClickEvent) {.caster.} =
  console.log jo

proc panMove(jo: JsObject as KonvaClickEvent) {.caster.} =
  console.log jo

proc panOut(jo: JsObject as KonvaClickEvent) {.caster.} =
  console.log jo


when isMainModule:
  var
    stage = newStage "board"
    layer = newLayer()
    circle = newCircle()


  block canvas:
    with stage:
      width = 500
      height = 500

    with layer:
      draggable = true

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
    stage.on "dragstart", panIn
    stage.on "dragmove", panMove
    stage.on "dragend", panOut

  block UI:
    let 
      zp = document.getElementById "zoom+"
      zm = document.getElementById "zoom-"

    zp.onclick = proc(e: Event) = 
      layer.scale = layer.scale + 0.1
      
    zm.onclick = proc(e: Event) = 
      layer.scale = layer.scale - 0.1