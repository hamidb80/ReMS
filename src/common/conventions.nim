template iff*(cond, val): untyped =
  if cond: val
  else: default type val

template iff*(cond, val, other): untyped =
  if cond: val
  else: other
