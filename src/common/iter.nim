iterator ritems*[T](s: openArray[T]): T = 
  for i in countdown(s.high, s.low):
    yield s[i]