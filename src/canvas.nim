import std/[with]
import konva


# proc makeClickable(k: KonvaShape) = 
#   k.on "click", proc(ke: JsObject as KonvaClickEvent) {.caster.} =
#     stopPropagate ke
#     k.draggable = true
#     app.transformer.nodes = [k]
#     app.layer.add app.transformer
#     app.layer.batchDraw
#     app.selectedObject = some KonvaObject k

# proc makeTransformable(k: KonvaShape) = 
#   k.on "transformend", proc(e: JsObject as KonvaClickEvent) {.caster.} =
#     k.width = k.width * k.scale.x
#     k.height = k.height * k.scale.y
#     k.scale = v(1, 1)


proc tempCircle*(x, y, r: Float, f: string): Circle =
  result = newCircle()
  with result:
    x = x
    y = y
    radius = r
    fill = f
    stroke = "black"
    strokeWidth = 2

# proc imageComponent*(x, y, r: Float, f: string): Circle =
#   newImageFromUrl data, proc(img: Image) =
#     with img:
#       x = app.lastMousePos.x
#       y = app.lastMousePos.y
#       makeClickable()
#       makeTransformable()
    
#     app.layer.add img
