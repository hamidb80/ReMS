import std/strutils
import std/macros


const noIndex* = -1

template `or`*(a, b: string): untyped =
  if a == "": b
  else: a

template iff*(cond, val): untyped =
  if cond: val
  else: default type val

template iff*(cond, val, other): untyped =
  if cond: val
  else: other


proc npop*(s: var seq) =
  discard s.pop

proc negate*(b: var bool) =
  b = not b

template str*(smth): untyped =
  $smth

template last*(smth): untyped =
  smth[^1]

proc noop* =
  discard


func findlen*(a, b: string): int =
  let i = a.find b
  if i == -1: -1
  else: i + b.len

template `|`*(f: float): untyped = 
  toInt f

template `~~`*(val, typ): untyped =
  cast[typ](val)

template forceSafety*(code): untyped =
  {.cast(gcsafe).}:
    {.cast(nosideeffect).}:
      code

template safeFail*(stmt): untyped =
  try: stmt
  except: discard

template `~>`*(expr, action): untyped =
  expr.mapIt action


macro noJs*(procDef): untyped = 
  ## discards under js
  quote:
    when not defined js:
      `procDef`