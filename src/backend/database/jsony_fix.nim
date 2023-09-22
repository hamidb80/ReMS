import std/parseutils

proc parseHook*[T: enum](s: string, i: var int, v: var T) =
  var temp: int
  inc i, parseInt(s, temp, i)
  v = T temp

proc dumpHook*(s: var string, v: enum) =
  s.add $v.int
