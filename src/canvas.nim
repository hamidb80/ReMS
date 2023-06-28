import std/[with]
import konva


# TODO store meta data https://konvajs.org/api/Konva.Node.html#setAttr

proc tempCircle*(x, y, r: Float, f: string): Circle =
  result = newCircle()
  with result:
    x = x
    y = y
    radius = r
    fill = f
    stroke = "black"
    strokeWidth = 2
