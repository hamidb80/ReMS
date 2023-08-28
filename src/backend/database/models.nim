import std/[tables, options, json, parseutils]
import jsony
import ../../common/[types, datastructures]

when defined js: import ponairi/pragmas
else: import ponairi


type
  UserRole* = enum
    urUser
    urAdmin

  User* = object
    id* {.primary, autoIncrement.}: Id
    username* {.index.}: string
    nickname*: string
    role*: UserRole

  AuthPlatform* = enum
    apNone
    apBaleBot
    apEmail

  Auth* = object
    id* {.primary, autoIncrement.}: Id
    user* {.references: User.id.}: Id
    platform*: AuthPlatform
    data*: string ## additional data like chat_id or username in that platform
    timestamp*: UnixTime

  InvitationSecret* = object
    ## must be deleted after usage
    id* {.primary, autoIncrement.}: Id
    user* {.references: User.id.}: Option[Id] # wanna create new user? or use existing one?
    secret* {.uniqueIndex.}: string
    expires*: UnixTime
    timestamp*: UnixTime

  Asset* = object
    id* {.primary, autoIncrement.}: Id
    # owner* {.references: User.id.}: Id
    name*: string
    size*: Bytes
    path*: Path
    # timestamp*: UnixTime
    # sha256*: string

  Note* = object
    id* {.primary, autoIncrement.}: Id
    # owner* {.references: User.id.}: Id
    data*: TreeNodeRaw[JsO]
    # timestamp*: UnixTime

  Board* = object
    id* {.primary, autoIncrement.}: Id
    # owner* {.references: User.id.}: Id
    title*: string
    description*: string
    screenshot* {.references: Asset.id.}: COption[Id]
    data*: BoardData
    # timestamp*: UnixTime

  TagValueType = enum
    tvtNone
    tvtInt
    tvtStr
    tvtDate
    tvtJson

  TagCreator* = enum
    tcUser   ## created by user
    tcSystem ## created by system

  TagLabel* = enum
    tlOrdinary        ## can be removed :: if it's not ordinary then its special

    # -- Redundant Tags
    tlOwner           ## owner
    tlTimestamp       ## creation time
    tlSize            ## size in bytes
    tlBoardScreenShot ## Screenshots that are taken from boards

    # -- Remembering System
    tlRememberIn
    tlRemembered

  Tag* = object
    id* {.primary, autoIncrement.}: Id
    owner* {.references: User.id.}: Id
    creator*: TagCreator
    label*: TagLabel
    can_repeated*: bool
    name*: string
    value_type*: TagValueType
    timestamp*: UnixTime

  RelationState* = enum
    rsFresh
    rsStale ## to mark as `processed` by system

  RelationCreationReason* = enum
    rcrUserInteraction
    rcrSystamAutomation

  Relation* = object
    id* {.primary, autoIncrement.}: Id
    user* {.references: User.id.}: Id
    tag* {.references: Tag.id.}: Id
    asset* {.references: Asset.id.}: Option[Id]
    board* {.references: Board.id.}: Option[Id]
    note* {.references: Note.id.}: Option[Id]
    int_value*: Option[int64]
    str_value*: Option[string]
    state*: RelationState
    created_due_to*: RelationCreationReason
    timestamp*: UnixTime

  RelationsCache* = object
    id* {.primary, autoIncrement.}: Id
    user* {.references: User.id.}: Id
    asset* {.references: Asset.id.}: Option[Id]
    board* {.references: Board.id.}: Option[Id]
    note* {.references: Note.id.}: Option[Id]
    tags*: JsonNode # Table[Id, seq[Relation]]

  Notification* = object
    id* {.primary, autoIncrement.}: Id
    user* {.references: User.id.}: Id
    content*: string
    timestamp*: UnixTime # set after sending

  ## I'm trying to implment Remember entries as `Tag`s
  ## that's what `int_value`, `str_value`, `value_type`
  ## is for

  # ----- custom types

proc parseHook*[T: enum](s: string, i: var int, v: var T) =
  var temp: int
  inc i, parseInt(s, temp, i)
  v = T temp

proc dumpHook*(s: var string, v: enum) =
  s.add $v.int

proc parseHook*(s: string, i: var int, v: var cstring) =
  var temp: string
  parseHook(s, i, temp)
  v = cstring temp

when not defined js:
  template defSqlJsonType(typename): untyped =
    proc sqlType*(t: typedesc[typename]): string = "TEXT"
    proc dbValue*(j: typename): DbValue = DbValue(kind: dvkString, s: toJson j)
    proc to*(src: DbValue, dest: var typename) =
      dest = fromJson(src.s, typename)

  defSqlJsonType JsonNode
  defSqlJsonType TreeNodeRaw[JsonNode]
  defSqlJsonType BoardData

  proc sqlType*(t: typedesc[Path]): string = "TEXT"
  proc dbValue*(p: Path): DbValue = DbValue(kind: dvkString, s: p.string)
  proc to*(src: DbValue, dest: var Path) =
    dest = src.s.Path

  proc sqlType*(t: typedesc[UnixTime]): string = "INT"
  proc dbValue*(p: UnixTime): DbValue = DbValue(kind: dvkInt, i: p.Id)
  proc to*(src: DbValue, dest: var UnixTime) =
    dest = src.i.UnixTime

  proc sqlType*(t: typedesc[Bytes]): string = "INT"
  proc dbValue*(p: Bytes): DbValue = DbValue(kind: dvkInt, i: p.int64)
  proc to*(src: DbValue, dest: var Bytes) =
    dest = src.i.Bytes

  func `%`*(p: Path): JsonNode = %p.string
  func `%`*(d: UnixTime): JsonNode = %d.int64
  func `%`*(b: Bytes): JsonNode = %b.int64

  # ----- basic operations

  proc createTables*(db: DbConn) =
    db.create(User, Auth, Asset, Note, Board, Tag, Relation, RelationsCache)

# ----- ...

func newNoteData*: TreeNodeRaw[JsonNode] =
  TreeNodeRaw[JsonNode](
    name: "root",
    children: @[],
    data: newJNull())
