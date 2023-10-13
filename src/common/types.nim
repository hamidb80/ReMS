import std/[times, tables, math, strutils, options]

import ./conventions


when defined js:
  import std/jsffi
  type
    Str* = cstring
    NativeJson* = JsObject
    NTable*[S: Str, T] = JsAssoc[S, T] ## native table
    Option*[T] = distinct JsObject

else:
  import std/json
  type
    Str* = string
    NativeJson* = JsonNode
    NTable*[A, B] = Table[A, B]
    Option*[T] = options.Option[T]

type
  SomeString* = string or cstring

  Id* = int64
  UnixTime* = distinct int64
  Path* = distinct string
  Mb* = distinct int
  Bytes* = distinct int64

  Degree* = distinct float
  Radian* = distinct float
  Percent* = range[0.0 .. 100.0]

  Tenth* = distinct int

  ColorChannel* = range[0..255]
  HexColorPack* = range[0..0xffffff_a] ## last part is for opacity
  HexColor* = range[0..0xffffff] ## last part is for opacity

  ConnectionCenterShapeKind* = enum
    # undirected connection
    ccsNothing
    ccsCircle
    ccsDiomand
    ccsSquare
    # directed connection
    ccsTriangle
    ccsDoubleTriangle

  # FIXME you can divide konva module into 2 parts: types & procs and simply import these types
  FontVariant* = enum
    fvVormal = "normal"
    fvSmallCaps = "small-caps"

  LineCap* = enum
    lcButt = "butt"
    lcRound = "round"
    lcSquare = "square"

  LineJoin* = enum
    ljMiter = "miter"
    ljRound = "round"
    ljBevel = "bevel"

  TransformsOption* = enum
    toAll = "all"
    toNone = "none"
    toPosition = "position"

  VerticalAlign* = enum
    vaTop = "top"
    vaMiddle = "middle"
    vaBottom = "bottom"

  HorizontalAlign* = enum
    hzLeft = "left"
    hzCenter = "center"
    hzRight = "right"

  WrapOption* = enum
    woWord = "word"
    woChar = "char"
    woNone = "none"

  FontStyle* = enum
    fsNormal = "normal"
    fsBold = "bold"
    fsItalic = "italic"
    fsItalicBold = "italic bold"

  TextDecoration* = enum
    tdNothing = ""
    tdLineThrough = "line-through"
    tdUnderline = "underline"

  CssCursor* = enum
    ccNone = ""
    ccMove = "move"
    ccZoom = "zoom-in"
    ccPointer = "pointer"
    ccResizex = "e-resize"
    ccGrabbing = "grabbing"


func getFields*[T](t: typedesc[T]): seq[string] =
  for k, v in fieldPairs(default t):
    result.add k

converter toBytes*(s: Mb): int = s.int * 1024 * 1024

func toUnixtime*(d: DateTime): UnixTime =
  d.toTime.toUnix.UnixTime

proc toDateTime*(u: UnixTime): DateTime =
  u.int64.fromUnix.utc


func degToRad*(d: Degree): Radian =
  Radian degToRad d.float

func tan*(d: Degree): float =
  tan float degToRad d

func cot*(d: Degree): float =
  cot float degToRad d

func `-`*(d: Degree): Degree =
  Degree 360 - d.float

# ----- Degree

func `<`*(a, b: Degree): bool {.borrow.}
func `==`*(a, b: Degree): bool {.borrow.}
func `<=`*(a, b: Degree): bool {.borrow.}
func `-`*(a, b: Degree): Degree {.borrow.}
func `+`*(a, b: Degree): Degree {.borrow.}
func `$`*(a: Degree): string {.borrow.}

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
  import std/jsffi

  func initNTable*[K: cstring, V](): NTable[K, V] =
    newJsAssoc[K, V]()

  func somec*[T](j: T): Option[T] {.importjs: "(@)".}

  func issome*[T](j: Option[T]): bool =
    cast[JsObject](j) != nil

  func get*[T](j: Option[T]): T =
    assert issome j
    cast[T](j)

  func nonec*[T](j: typedesc[T]): Option[T] =
    Option[T](nil)
