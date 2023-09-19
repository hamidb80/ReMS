import std/[tables, json, parseutils]
import ../../common/[types, datastructures]

when defined js: import ponairi/pragmas
else: import ponairi


type # database models
  UserRole* = enum
    urUser
    urAdmin

  User* = object
    id* {.primary, autoIncrement.}: Id
    username* {.index.}: Str
    nickname*: Str
    role*: UserRole

  AuthPlatform* = enum
    apNone
    apBaleBot
    apEmail

  Auth* = object
    id* {.primary, autoIncrement.}: Id
    user* {.references: User.id.}: Id
    platform*: AuthPlatform
    data*: Str ## additional data like chat_id or username in that platform
    timestamp*: UnixTime

  InvitationSecret* = object
    ## must be deleted after usage
    id* {.primary, autoIncrement.}: Id
    user* {.references: User.id.}: Option[Id] # wanna create new user? or use existing one?
    secret* {.uniqueIndex.}: Str
    expiration*: UnixTime
    creation*: UnixTime

  Asset* = object
    id* {.primary, autoIncrement.}: Id
    name*: Str # name without extention
    mime*: Str
    size*: Bytes
    path*: Path # where is it stored?

  Note* = object
    id* {.primary, autoIncrement.}: Id
    data*: TreeNodeRaw[NativeJson]

  Board* = object
    id* {.primary, autoIncrement.}: Id
    title*: Str
    screenshot* {.references: Asset.id.}: Option[Id]
    data*: BoardData

  TagValueType* = enum
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
    icon*: string
    value_type*: TagValueType

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
    number_value*: Option[float]
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

type # view models
  AssetItemView* = object
    id*: Id
    name*: Str
    mime*: Str
    size*: Bytes
    # owner*: Id
    # timestamp*: UnixTime

  BoardPreview* = object
    id*: Id
    title*: Str
    screenshot*: Option[Id]

  TagUserCreate* = object
    can_repeated*: bool
    name*: Str
    icon*: Str
    value_type*: TagValueType

  GithubCodeEmbed* = object
    styleLink*: string
    htmlCode*: string


when not defined js:
  import jsony
  include jsony_fix


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

  proc parseHook*(s: string, i: var int, v: var cstring) =
    var temp: string
    parseHook(s, i, temp)
    v = cstring temp

  # ----- basic operations

  proc createTables*(db: DbConn) =
    db.create(User, Auth, Asset, Note, Board, Tag, Relation, RelationsCache)

# ----- ...

func newNoteData*: TreeNodeRaw[JsonNode] =
  TreeNodeRaw[JsonNode](
    name: "root",
    children: @[],
    data: newJNull())
