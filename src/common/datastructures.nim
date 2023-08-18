import std/[tables, sets, strutils]
import prettyvec
import ./types

type
  SeqTable[K, V] = Table[K, seq[V]]
  Graph*[T] = Table[T, HashSet[T]]


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


type
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


type

  FontConfig* = object
    family*: string
    size*: int
    style*: FontStyle
    # lineHeight: Float

  ColorTheme* = object
    bg*, fg*, st*: HexColor

  VisualNodeData* = object
    id*: string
    palletei*: Natural
    text*: string
    imagePath*: string
    font*: FontConfig
    position*: Vec2Obj # top left

  EdgeData* = object
    head*: string
    tail*: string
    config*: EdgeConfig

  BoardData* = object
    objects*: Table[string, VisualNodeData]
    edges*: seq[EdgeData]

  EdgeConfig* = object
    theme*: ColorTheme
    width*: Tenth
    centerShape*: ConnectionCenterShapeKind # TODO



func c*(bg, fg, st: int): ColorTheme =
  ColorTheme(
    bg: bg.HexColor,
    fg: fg.HexColor,
    st: st.HexColor)
