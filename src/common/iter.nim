iterator ritems*[T](s: openArray[T]): T = 
  for i in countdown(s.high, s.low):
    yield s[i]


func remove*[T](s: var seq[T], item: T) = 
  let i = s.find item
  if i != -1:
    del s, i

template deleteIt*(s: var seq, cond: untyped) = 
  for i, it {.inject.} in s:
    if cond:
      delete s, i
      break

  
proc incRound*[E: enum](i: var E) =
  i =
    if i == E.high: E.low
    else: succ i
