import std/[times, tables, math, strutils]


when defined js:
  import std/jsffi

  type
    Str* = cstring
    JsO* = JsObject
    CTable*[S: Str, T] = JsAssoc[S, T]
else:
  import std/json
  type
    Str* = string
    JsO* = JsonNode
    CTable*[A, B] = Table[A, B]


type
  Id* = int64
  UnixTime* = distinct int64
  Path* = distinct string
  Mb* = distinct int
  Bytes* = distinct int64


  Degree* = distinct float
  Radian* = distinct float

  Tenth* = distinct int
  HexColor* = distinct int

  ConnectionCenterShapeKind* = enum
    # undirected connection
    ccsNothing
    ccsCircle
    ccsDiomand
    ccsSquare
    # directed connection
    ccsTriangle
    ccsDoubleTriangle

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


converter toHex*(c: HexColor): string =
  '#' & toHex(c.int, 6)


# TODO move it to js module
when defined js:
  import std/jsffi

  func initCTable*[K: cstring, V](): CTable[K, V] =
    newJsAssoc[K, V]()
