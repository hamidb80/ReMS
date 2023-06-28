template `Δy`*(e): untyped = e.deltaY
template `Δx`*(e): untyped = e.deltaX
template `||`*(v): untyped = v.asScalar

template iff*(cond, val): untyped =
  if cond: val
  else: default type val
