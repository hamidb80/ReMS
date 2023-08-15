import std/times


when defined js:
  type Str* = cstring
else:
  type Str* = string

type
  Id* = int64
  UnixTime* = distinct int64
  Path* = distinct string
  Mb* = distinct int
  Bytes* = distinct int64


func getFields*[T](t: typedesc[T]): seq[string] =
  for k, v in fieldPairs(default t):
    result.add k

converter toBytes*(s: Mb): int = s.int * 1024 * 1024

func toUnixtime*(d: DateTime): UnixTime =
  d.toTime.toUnix.UnixTime
