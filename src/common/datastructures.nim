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


func add1[T](g: var Graph[T], a, b: T) =
  if a notin g:
    g[a] = initHashSet[T]()

  g[a].incl b

func remove1[T](g: var Graph[T], a, b: T) =
  if a in g:
    g[a].excl b

func addConn*[T](g: var Graph[T], conn: Slice[T]) =
  g.add1 conn.a, conn.b
  g.add1 conn.b, conn.a

func removeConn*[T](g: var Graph[T], conn: Slice[T]) =
  g.remove1 conn.a, conn.b
  g.remove1 conn.b, conn.a

func removeNode*[T](g: var Graph[T], node: T) =
  if node in g:
    let neighbours = g[node]
    g.del node
    for n in neighbours:
      g[n].excl node


type
  TreeNodeRec*[D] = ref object ## used in frontend
    father*: TreeNodeRec[D]
    children*: seq[TreeNodeRec[D]]
    data*: D

  TreeNodeRaw*[D] = ref object ## used in frontend
    name*: Str
    children*: seq[TreeNodeRaw[D]]
    data*: D

  TreeNode[D] = concept t
    t.children is seq[typeof t]

  TreePath* = seq[int]

func isLeaf*(tn: TreeNodeRec or TreeNodeRaw): bool =
  tn.children.len == 0

func isRoot*(tn: TreeNodeRec): bool =
  tn.father == nil

func follow*[D](n: TreeNode[D], path: TreePath): auto =
  result = n
  for i in path:
    result = result.children[i]


type
  ColorTheme* = object
    bg*, fg*, st*: HexColorPack

  FontConfig* = object
    family*: Str
    size*: int
    style*: FontStyle
    # lineHeight: Float

  VirtualNodeDataKind* = enum
    vndkText
    vndkImage

  VisualNodeConfig* = object
    id*: int
    theme*: ColorTheme
    data*: VisualNodeData
    font*: FontConfig  # TODO move this to `VisualNodeData`
    position*: Vec2Obj # top left
    messageIdList*: seq[Id]

  VisualNodeData* = object
    case kind*: VirtualNodeDataKind
    of vndkText:
      text*: Str
    of vndkImage:
      url*: Str
      width*, height*: float

  EdgeConfig* = object
    theme*: ColorTheme
    width*: Tenth
    centerShape*: ConnectionCenterShapeKind

  ConnectionPointKind* = enum
    cpkHead, cpkTail

  EdgeData* = object
    points*: seq[Id] ## array[ConnectionPointKind, Id]
    config*: EdgeConfig

  BoardData* = object
    objects*: NTable[Str, VisualNodeConfig]
    edges*: seq[EdgeData]

  NoteData* = TreeNodeRaw[NativeJson]


func c*(bg, fg, st: int): ColorTheme =
  ColorTheme(
    bg: opaque bg,
    fg: opaque fg,
    st: opaque st)
