import std/[times, tables, math, strutils, options, sequtils]

import prettyvec
import ./conventions


when defined js:
  import std/jsffi
  type
    Str* = cstring
    NativeJson* = JsObject
    NTable*[S: Str, T] = JsAssoc[S, T] ## native table
    Option*[T] = distinct JsObject
    Id* = int

else:
  import std/json
  type
    Str* = string
    NativeJson* = JsonNode
    NTable*[A, B] = Table[A, B]
    Option*[T] = options.Option[T]
    Id* = int64

type
  SomeString* = string or cstring

  UnixTime* = distinct int64
  Path* = distinct string
  Mb* = distinct int
  Bytes* = distinct int64

  Degree* = distinct float
  Radian* = distinct float
  Percent* = range[0.0 .. 100.0]

  Axis* = enum
    aVertical
    aHorizontal

  Tenth* = distinct int

  Vector* = Vec2Obj

  Region = range[1..4]

  Size* = object
    width*, height*: float

  Area* = object
    x1*, x2*, y1*, y2*: float

  ColorChannel* = range[0..255]
  HexColorPack* = range[0..0xffffff_a] ## last part is for opacity
  HexColor* = range[0..0xffffff] ## last part is for opacity

  ConnectionCenterShapeKind* = enum
    # undirected connection
    ccsCircle = "Circle"
    ccsDiamond = "Diamond"
    ccsSquare = "Square"
    # directed connection
    ccsTriangle = "Triangle"
    ccsDoubleTriangle = "Double Triangle"

  CssCursor* = enum
    ccNone = ""
    ccMove = "move"
    ccZoom = "zoom-in"
    ccPointer = "pointer"
    ccResizex = "e-resize"
    ccGrabbing = "grabbing"


func toFloat*[F: Somefloat](f: F): F = f


func getFields*[T](t: typedesc[T]): seq[string] =
  for k, v in fieldPairs(default t):
    result.add k

converter toBytes*(s: Mb): int = s.int * 1024 * 1024


func toUnixtime*(d: DateTime): UnixTime =
  d.toTime.toUnix.UnixTime

proc unow*: UnixTime =
  toUnixtime now()

proc toDateTime*(u: UnixTime): DateTime =
  u.int64.fromUnix.utc


func `°`*(θ: float): Degree = Degree θ
func `°`*(θ: int): Degree = Degree toFloat θ


func v*[N1, N2: SomeNumber](x: N1, y: N2): Vector =
  Vector(x: x.toFloat, y: y.toFloat)

func v*(s: Size): Vector =
  v(s.width, s.height)

func center*(ps: seq[Vector]): Vector =
  var acc = vec2(0, 0)
  for p in ps:
    acc = acc + p
  acc / toFloat len ps


func asScalar*(v: Vector): float =
  assert v.x == v.y, $v
  v.x

converter toSize*(v: Vector): Size =
  Size(width: v.x, height: v.y)

func normalize*(θ: Degree): Degree =
  let
    d = θ.float
    (i, f) = splitDecimal d
    i′ = (i mod 360)

  if d >= 0: ° i′ + f
  else: ° 360 + i′ + f

func degToRad*(d: Degree): Radian =
  Radian degToRad d.float

func tan*(d: Degree): float =
  tan float degToRad d

func cot*(d: Degree): float =
  cot float degToRad d

func `-`*(d: Degree): Degree =
  Degree -d.float

func `<`*(a, b: Degree): bool {.borrow.}
func `==`*(a, b: Degree): bool {.borrow.}
func `<=`*(a, b: Degree): bool {.borrow.}
func `-`*(a, b: Degree): Degree {.borrow.}
func `+`*(a, b: Degree): Degree {.borrow.}
func `$`*(a: Degree): string {.borrow.}


func `+`*[T](s: Slice[T], m: T): Slice[T] =
  s.a+m .. s.b+m

func `-`*(a: Vector): Vector = v(-a.x, -a.y)
func topLeft*(a: Area): Vector = v(a.x1, a.y1)
func topRight*(a: Area): Vector = v(a.x2, a.y1)
func bottomLeft*(a: Area): Vector = v(a.x1, a.y2)
func bottomRight*(a: Area): Vector = v(a.x2, a.y2)
func center*(a: Area): Vector = v(a.x1+a.x2, a.y1+a.y2) / 2
func xs*(a: Area): Slice[float] = a.x1 .. a.x2
func ys*(a: Area): Slice[float] = a.y1 .. a.y2

func `+`*(a: Area, v: Vector): Area =
  Area(
    x1: a.x1+v.x,
    x2: a.x2+v.x,
    y1: a.y1+v.y,
    y2: a.y2+v.y)

func area*(v: Vector): Area =
  Area() + v

func contains*(a: Area, v: Vector): bool =
  v.x in a.x1..a.x2 and
  v.y in a.y1..a.y2

func contains*(a, b: Area): bool =
  a.x1 < b.x1 and
  a.x2 > b.x2 and
  a.y1 < b.y1 and
  a.y2 > b.y2

func intersects*[T](a, b: Slice[T]): bool =
  a.a in b or
  a.b in b or
  b.a in a or
  b.b in a

func intersects*(a, b: Area): bool =
  intersects(a.xs, b.xs) and
  intersects(a.ys, b.ys)

func `*`*(a: seq[Vector], scale: float): seq[Vector] =
  mapit a, it * scale

func onBorder*(axis: Axis; limit: float; θ: Degree): Vector =
  case axis
  of aVertical:
    let
      m = tan θ
      y = m * limit

    v(limit, -y)

  of aHorizontal:
    let
      m⁻¹ = cot θ
      x = m⁻¹ * limit

    v(-x, limit)

func onBorder*(dd: (Axis, float); θ: Degree): Vector =
  onBorder dd[0], dd[1], θ

func rectSide*(a: Area; r: Region): tuple[axis: Axis; limit: float] =
  case r
  of 1: (aVertical, a.x2)
  of 3: (aVertical, a.x1)
  of 2: (aHorizontal, a.y1)
  of 4: (aHorizontal, a.y2)

func arctan*(v: Vector): Degree =
  normalize Degree radToDeg arctan2(-v.y, v.x)

func whichRegion*(θ: Degree; a: Area): Region =
  ## divides the rectangle into 4 regions according to its diameters
  let
    d = a.topRight - a.center
    λ = normalize arctan d
  assert θ >= 0.°
  assert λ >= 0.°

  if θ <= λ: 1
  elif θ <= 180.° - λ: 2
  elif θ <= 180.° + λ: 3
  elif θ <= 360.° - λ: 4
  else: 1


# ----- Tenth

func `==`*(a, b: Tenth): bool {.borrow.}

func `$`*(t: Tenth): string =
  let
    n = t.int
    a = n div 10
    b = n mod 10

  $a & '.' & $b

func toFloat*(t: Tenth): float =
  t.int / 10

func toTenth*(f: float): Tenth =
  let n = toint f * 10
  Tenth n


func color*(hc: HexColorPack): HexColor =
  hc shr 4

func opacity*(hc: HexColorPack): range[0.0 .. 1.0] =
  (hc mod 16) / 10

func opaque*(hc: HexColor): HexColorPack =
  (hc shl 4) + 10

func red*(hc: HexColor): ColorChannel =
  hc div 256 div 256

func green*(hc: HexColor): ColorChannel =
  hc div 256 mod 256

func blue*(hc: HexColor): ColorChannel =
  hc mod 256


func toHex*(c: HexColor): Str =
  '#' & toHex(c.int, 6)

func toRgba*(hc: HexColorPack): Str =
  let
    c = hc.color
    o = hc.opacity
  "rgba(" & $c.red & ", " & $c.green & ", " & $c.blue & ", " & $o & ")"

func toColorString*(c: HexColorPack): Str =
  if c.opacity == 1.0:
    toHex c.color
  else:
    toRgba c

func parseHexColorPack*(s: string): HexColorPack =
  let
    hasPrefix = s[0] == '#'
    number = parseHexInt:
      if hasPrefix: s[1..^1]
      else: s
    size = s.len - iff(hasPrefix, 1, 0)

  case size
  of 6: opaque HexColor number
  of 7: HexColorPack number
  else: raise newException(ValueError, "invalid length, expected 6 or 7 but got: " & $number)

# TODO move it to js module
when defined js:
  func initNTable*[K: cstring, V](): NTable[K, V] =
    newJsAssoc[K, V]()

  func somec*[T](j: T): Option[T] {.importjs: "(@)".}

  func isNone*[T](j: Option[T]): bool =
    cast[JsObject](j) == nil

  func isSome*[T](j: Option[T]): bool =
    not isNone j

  func get*[T](j: Option[T]): T =
    assert issome j
    cast[T](j)

  func nonec*[T](j: typedesc[T]): Option[T] =
    Option[T](nil)
