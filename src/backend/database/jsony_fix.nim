## https://github.com/treeform/jsony/issues/77
## include it wherever you import jsony

import std/parseutils

proc parseHook*[T: enum](s: string, i: var int, v: var T) =
  var temp: int
  inc i, parseInt(s, temp, i)
  v = T temp

proc dumpHook*(s: var string, v: enum) =
  add s, $(int v)
