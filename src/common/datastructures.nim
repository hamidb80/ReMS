import std/[tables, sets]
import ./types

type
  SeqTable[K, V] = Table[K, seq[V]]
  Graph*[T] = Table[T, HashSet[T]]

  TreeNodeRec*[D] = ref object ## used in frontend
    father*: TreeNodeRec[D]
    children*: seq[TreeNodeRec[D]]
    data*: D

  TreeNodeRaw*[D] = ref object ## used in frontend
    name*: Str
    children*: seq[TreeNodeRaw[D]]
    data*: D

  TreePath* = seq[int]


func isLeaf*(tn: TreeNodeRec or TreeNodeRaw): bool =
  tn.children.len == 0

func isRoot*(tn: TreeNodeRec): bool =
  tn.father == nil


func add*[K, V](st: var SeqTable[K, V], key: K, val: V) =
  if key in st:
    st[key].add val
  else:
    st[key] = @[val]


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
