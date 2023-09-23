import std/[json, parseutils]
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
    name*: Str  # name without extention
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

  Palette* = object
    id* {.primary, autoIncrement.}: Id
    user* {.references: User.id.}: Option[Id]
    name* {.uniqueIndex.}: Str
    colorThemes*: seq[ColorTheme]

  TagValueType* = enum
    tvtNone = "none"
    tvtStr = "text"
    tvtFloat = "float"
    tvtInt = "int"
    tvtDate = "date"
    tvtJson = "JSON"

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
    tlReserved1
    tlReserved2
    tlReserved3
    tlReserved4
    tlReserved5
    tlReserved6
    tlReserved7
    tlReserved8
    tlReserved9
    tlReserved10

    # -- Remembering System
    tlRememberIn
    tlRemembered


  Tag* = object
    id* {.primary, autoIncrement.}: Id
    owner* {.references: User.id.}: Id
    creator*: TagCreator
    label*: TagLabel
    can_be_repeated*: bool
    name*: Str
    icon*: Str
    theme*: ColorTheme
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
    fval*: Option[float]
    ival*: Option[int]
    sval*: Option[Str]
    state*: RelationState
    created_due_to*: RelationCreationReason
    timestamp*: UnixTime

  RelValuesByTagId* = NTable[Str, seq[Str]]

  RelationsCache* = object ## one to one relation with Note/Board/Asset
    id* {.primary, autoIncrement.}: Id
    user* {.references: User.id.}: Id
    asset* {.references: Asset.id.}: Option[Id]
    board* {.references: Board.id.}: Option[Id]
    note* {.references: Note.id.}: Option[Id]
    active_rels_values*: RelValuesByTagId ## active relation values grouped by tag id

  Notification* = object
    id* {.primary, autoIncrement.}: Id
    user* {.references: User.id.}: Id
    content*: Str
    timestamp*: UnixTime # set after sending


type # view models
  AssetItemView* = object
    id*: Id
    name*: Str
    mime*: Str
    size*: Bytes
    # activeRelsValues*: RelValuesByTagId

  NoteItemView* = object
    id*: Id
    data*: TreeNodeRaw[NativeJson]
    activeRelsValues*: RelValuesByTagId

  BoardItemView* = object
    id*: Id
    title*: Str
    screenshot*: Option[Id]

  GithubCodeEmbed* = object
    styleLink*: Str
    htmlCode*: Str


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
  defSqlJsonType NTable
  defSqlJsonType ColorTheme
  defSqlJsonType seq[ColorTheme]

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

  proc defaultPalette(db: DbConn) =
    db.insert Palette(
      name: "default",
      colorThemes: @[
        ColorTheme(bg: 0xffffff_0, fg: 0x889bad_a, st: 0xa5b7cf_a), # transparent
        c(0xffffff, 0x889bad, 0xa5b7cf), # white
        c(0xecedef, 0x778696, 0x9eaabb), # smoke
        c(0xdfe2e4, 0x617288, 0x808fa6), # road
        c(0xfef5a6, 0x958505, 0xdec908), # yellow
        c(0xffdda9, 0xa7690e, 0xe99619), # orange
        c(0xffcfc9, 0xb26156, 0xff634e), # red
        c(0xfbc4e2, 0xaf467e, 0xe43e97), # peach
        c(0xf3d2ff, 0x7a5a86, 0xc86fe9), # pink
        c(0xdac4fd, 0x7453ab, 0xa46bff), # purple
        c(0xd0d5fe, 0x4e57a3, 0x7886f4), # purpleLow
        c(0xb6e5ff, 0x2d7aa5, 0x399bd3), # blue
        c(0xadefe3, 0x027b64, 0x00d2ad), # diomand
        c(0xc4fad6, 0x298849, 0x25ba58), # mint
        c(0xcbfbad, 0x479417, 0x52d500), # green
        c(0xe6f8a0, 0x617900, 0xa5cc08), # lemon
        c(0x424242, 0xececec, 0x919191), # dark
      ])

  proc createTables*(db: DbConn) =
    db.create(User, Auth, Asset, Note, Board, Tag, Relation, RelationsCache, Palette)
    try:
      db.defaultPalette()
    except:
      discard

# ----- ...

func newNoteData*: TreeNodeRaw[JsonNode] =
  TreeNodeRaw[JsonNode](
    name: "root",
    children: @[],
    data: newJNull())

func hasValue*(t: Tag): bool =
  t.value_type != tvtNone
