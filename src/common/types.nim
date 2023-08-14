func getFields*[T](t: typedesc[T]): seq[string] =
  for k, v in fieldPairs(default t):
    result.add k

type Mb* = distinct int
converter toBytes*(s: Mb): int = s.int * 1024 * 1024
