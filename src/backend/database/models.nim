import std/[json, parseutils]
import ../../common/[types, datastructures]

when defined js: import ponairi/pragmas
else: import ponairi

# TODO change name 'board' to 'board'

type # database models
  UserRole* = enum
    urUser
    urAdmin

  User* = object
    id* {.primary, autoIncrement.}: Id
    username* {.uniqueIndex.}: Str
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
    name*: Str  # name with extention
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
    user* {.references: User.id.}: Option[Id]         ## owner
    name* {.uniqueIndex.}: Str
    colorThemes*: seq[ColorTheme]

  TagValueType* = enum
    tvtNone
    tvtStr
    tvtFloat
    tvtInt
    tvtDate
    tvtJson

  TagCreator* = enum
    tcUser   ## created by user
    tcSystem ## created by system

  TagLabel* = enum
    tlOrdinary         ## can be removed :: if it's not ordinary then its special

    tlOwner            ## owner
    tlTimestamp        ## creation time
    tlSize             ## size in bytes
    tlName             ## name
    tlMime             ## mime type of a file
    tlBoardScreenShot  ## screenshots that are taken from boards
    tlTextContent      ## raw text
    tlLike             ## default like tag

    tlNoteOfNode       ## notes [id@ival] that are connected to nodes[uuid@sval] of board
    tlNoteHighlight    ##
    tlNoteComment      ## a note (as comment) that refers to main note (ival)
    tlNoteCommentReply ## reply to another comment

    tlPrivate          ## everything is public except when it has private tag
    tlHasAccess        ## tag with username of the person as value - is used with private

    tlFollows          ## user => ival (user.id)

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
    tlReserved11
    tlReserved12

    # -- Remembering System
    tlRememberIn
    tlRemembered


  Tag* = object
    ## most of the tags are primarily made for searching
    ## purposes and have redundent data

    id* {.primary, autoIncrement.}: Id
    owner* {.references: User.id.}: Id
    creator*: TagCreator
    label*: TagLabel
    name*: Str
    icon*: Str
    show_name*: bool
    is_private*: bool
    can_be_repeated*: bool
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
    tag* {.references: Tag.id, index.}: Id            ## originates from
    user* {.references: User.id.}: Option[Id]         ## owner

    asset* {.references: Asset.id, index.}: Option[Id]
    board* {.references: Board.id, index.}: Option[Id]
    node* {.references: Relation.id, index.}: Option[Id]
    note* {.references: Note.id, index.}: Option[Id]

    fval*: Option[float]
    ival*: Option[int]
    sval*: Option[Str]
    refers*: Option[Id]                               ## arbitrary row id

    state*: RelationState
    created_due_to*: RelationCreationReason
    timestamp*: UnixTime                              ## creation time

  RelValuesByTagId* = NTable[Str, seq[Str]]

  RelationsCache* = object ## one to one relation with Note/Board/Asset
    id* {.primary, autoIncrement.}: Id
    user* {.references: User.id.}: Id
    asset* {.references: Asset.id, index.}: Option[Id]
    board* {.references: Board.id, index.}: Option[Id]
    note* {.references: Note.id, index.}: Option[Id]
    active_rels_values*: RelValuesByTagId ## active relation values grouped by tag id

  Notification* = object
    id* {.primary, autoIncrement.}: Id
    user* {.references: User.id.}: Id
    content*: Str
    timestamp*: UnixTime # set after sending

type # view models
  EntityClass* = enum
    ecNote
    ecAsset
    ecBoard

  QueryOperator* = enum
    # prefix
    qoExists    ## ?? EXISTS
    qoNotExists ## ?! NOT EXISTS
    # infix
    qoLess      ## <
    qoLessEq    ## <=
    qoEq        ## ==
    qoNotEq     ## !=
    qoMoreEq    ## =>
    qoMore      ## >
    qoLike      ## ~ LIKE string pattern

  TagCriteria* = object
    label*: TagLabel
    tagId*: Id
    valueType*: TagValueType

    operator*: QueryOperator
    value*: Str

  ExploreQuery* = object
    criterias*: seq[TagCriteria]
    limit*: Natural
    skip*: int


  AssetItemView* = object
    id*: Id
    name*: Str
    mime*: Str
    size*: Bytes
    activeRelsValues*: RelValuesByTagId

  NoteItemView* = object
    id*: Id
    data*: TreeNodeRaw[NativeJson]
    activeRelsValues*: RelValuesByTagId

  BoardItemView* = object
    id*: Id
    title*: Str
    screenshot*: Option[Id]
    activeRelsValues*: RelValuesByTagId

  GithubCodeEmbed* = object
    styleLink*: Str
    htmlCode*: Str

  LoginForm* = object
    pass*: Str

  LinkPreviewData* = object
    title*: Str
    desc*: Str
    image*: Str
    # timestamp*: string # TODO
      # cardType twitter:card


func newNoteData*: TreeNodeRaw[JsonNode] =
  TreeNodeRaw[JsonNode](
    name: "root",
    children: @[],
    data: newJNull())

func hasValue*(t: Tag): bool =
  t.value_type != tvtNone

func isAdmin*(u: User): bool =
  u.role == urAdmin

func columnName*(vt: TagValueType): string =
  case vt
  of tvtNone: ""
  of tvtFloat: "fval"
  of tvtInt, tvtDate: "ival"
  of tvtJson, tvtStr: "sval"

func isInfix*(qo: QueryOperator): bool =
  qo in qoLess..qoLike

func `$`*(qo: QueryOperator): string =
  case qo
  of qoExists: "??"
  of qoNotExists: "?!"
  of qoLess: "<"
  of qoLessEq: "<="
  of qoEq: "=="
  of qoNotEq: "!="
  of qoMoreEq: ">="
  of qoMore: ">"
  of qoLike: "LIKE" # FIXME security issue

func `$`*(tvt: TagValueType): string =
  case tvt
  of tvtNone: "none"
  of tvtStr: "text"
  of tvtFloat: "float"
  of tvtInt: "int"
  of tvtDate: "date"
  of tvtJson: "JSON"


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
