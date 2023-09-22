const noIndex* = -1

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

proc noop* = 
  discard
