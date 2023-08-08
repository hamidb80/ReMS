import std/[tables, sets]

type
  Graph*[T] = Table[T, HashSet[T]]


func add[T](g: var Graph[T], key, val: T) = 
  if key notin g:
    g[key] = initHashSet[T]()

  g[key].incl val

func remove[T](g: var Graph[T], key, val: T) = 
  if key in g:
    g[key].decl val


func addConn*[T](g: var Graph[T], conn: Slice[T]) = 
  g.add conn.a, conn.b
  g.add conn.b, conn.a

func removeConn*[T](g: var Graph[T], conn: Slice[T]) = 
  g.remove conn.a, conn.b
  g.remove conn.b, conn.a