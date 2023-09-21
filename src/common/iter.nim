iterator ritems*[T](s: openArray[T]): T = 
  for i in countdown(s.high, s.low):
    yield s[i]


func remove*[T](s: var seq[T], item: T) = 
  let i = s.find item
  case i
  of -1: discard
  else: s.del i

template deleteIt*(s: var seq, cond: untyped) = 
  for i, it {.inject.} in s:
    if cond:
      delete s, i
      break