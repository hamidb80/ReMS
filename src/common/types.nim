func getFields*[T](t: typedesc[T]): seq[string] = 
  for k, v in fieldPairs(default t):
    result.add k
