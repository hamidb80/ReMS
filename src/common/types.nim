import std/[times, tables, math]


when defined js:
  import std/jsffi

  type
    Str* = cstring
    JsO* = JsObject
else:
  import std/json
  type
    Str* = string
    JsO* = JsonNode

type
  Id* = int64
  UnixTime* = distinct int64
  Path* = distinct string
  Mb* = distinct int
  Bytes* = distinct int64


  Degree* = distinct float
  Radian* = distinct float



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
