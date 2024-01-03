import std/[json, algorithm]

import ../../common/[types, datastructures]

when defined js:
  import ponairi/pragmas
  type SecureHash = string
else:
  import std/sha1
  import ponairi


type # database models
  UserRole* = enum
    urUser
    urAdmin

  User* = object
    id* {.primary, autoIncrement.}: Id
    username* {.uniqueIndex.}: Str
    nickname*: Str
    role*: UserRole

  Invitation* = object
    id* {.primary, autoIncrement.}: Id
    secret*: Str # TODO hash it
    data*: JsonNode
    timestamp*: UnixTime

  Auth* = object
    id* {.primary, autoIncrement.}: Id
    user* {.references: User.id.}: Id
    bale* {.references: User.id.}: Option[Id] # bale chat id
    email*: Option[Str]
    hashed_pass*: Option[SecureHash]

  Asset* = object
    id* {.primary, autoIncrement.}: Id
    name*: Str  # name with extention
    mime*: Str
    size*: Bytes
    path*: Path # where is it stored?

    owner* {.references: User.id.}: Id
    is_private*: bool
    deleted_at*: Option[UnixTime]

  Note* = object
    id* {.primary, autoIncrement.}: Id
    data*: NoteData 

    owner* {.references: User.id.}: Id
    is_private*: bool
    deleted_at*: Option[UnixTime]

  Board* = object
    id* {.primary, autoIncrement.}: Id
    title*: Str
    screenshot* {.references: Asset.id.}: Option[Id]
    data*: BoardData

    owner* {.references: User.id.}: Id
    is_private*: bool
    deleted_at*: Option[UnixTime]

  Palette* = object
    id* {.primary, autoIncrement.}: Id
    user* {.references: User.id.}: Option[Id]         ## owner
    name* {.uniqueIndex.}: Str
    color_themes*: seq[ColorTheme]

  TagValueType* = enum
    tvtNone
    tvtStr
    tvtFloat
    tvtInt
    tvtDate
    tvtJson

  TagLabel* = enum     ## special tags
    # -- hidden or special view component
    tlForwarded        ## a note that is forwarded from another user
    tlNoteComment      ## a note (as comment) that refers to main note (refers)
    tlNoteCommentReply ## reply to another comment

    tlBoardNode        ##
    tlBoardNodeNote    ##

    tlFollows          ## user => refers (user.id)
    tlNotification     ##

    # -- visible
    tlOwner            ## owner
    tlTimestamp        ## creation time
    tlSize             ## size in bytes
    tlFileName         ## name of file
    tlMime             ## mime type of a file
    tlPrivate          ## everything is public except when it has private tag

    tlHasAccess        ## tag with username of the person as value - is used with private
    tlNoteHighlight    ##
    tlTextContent      ## raw text
    tlBoardScreenShot  ## screenshots that are taken from boards

    tlLike             ##
    tlImportant        ##
    tlLater            ##

    tlRememberIn       ##
    tlRemembered       ##

  Tag* = object
    ## most of the tags are primarily made for searching
    ## purposes and have redundent data

    id* {.primary, autoIncrement.}: Id
    owner* {.references: User.id.}: Option[Id] # NULL means global
    label*: Option[TagLabel]
    name*: Str
    icon*: Str
    show_name*: bool
    is_private*: bool
    can_be_repeated*: bool
    theme*: ColorTheme
    value_type*: TagValueType
    # TODO tag with "open/closed enums" values or a range

  NotificationKind* = enum
    nkLoginBale

  RelationState* = enum
    rsFresh
    rsStale ## to mark as processed or expired by the system

  Relation* = object
    id* {.primary, autoIncrement.}: Id
    tag* {.references: Tag.id, index.}: Id            ## originates from
    kind* {.index.}: Option[int]                      ## sub label according to tag
    user* {.references: User.id.}: Option[Id]         ## owner

    asset* {.references: Asset.id, index.}: Option[Id]
    board* {.references: Board.id, index.}: Option[Id]
    node* {.references: Relation.id, index.}: Option[Id]
    note* {.references: Note.id, index.}: Option[Id]

    fval*: Option[float]
    ival*: Option[int]
    sval*: Option[Str]
    refers*: Option[Id]                               ## arbitrary row id

    info*: Str                                        ## additional information
    state*: RelationState
    timestamp*: UnixTime                              ## creation time

  RelValuesByTagId* = NTable[Str, seq[Str]]

  RelationsCache* = object ## one to one relation with Note/Board/Asset
    id* {.primary, autoIncrement.}: Id
    user* {.references: User.id.}: Id
    asset* {.references: Asset.id, index.}: Option[Id]
    board* {.references: Board.id, index.}: Option[Id]
    note* {.references: Note.id, index.}: Option[Id]
    active_rels_values*: RelValuesByTagId ## active relation values grouped by tag id

type # view models
  UserCache* = object
    exp*: int
    account*: User
    defaultTags*: array[TagLabel, Id]

  EntityClass* = enum
    ecNote = "note"
    ecAsset = "asset"
    ecBoard = "board"

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
    qoSubStr    ## ~ substring check

  TagCriteria* = object
    label*: Option[TagLabel]
    tagId*: Id
    value_type*: TagValueType
    operator*: QueryOperator
    value*: Str

  ExploreQuery* = object
    searchCriterias*: seq[TagCriteria]
    sortCriteria*: Option[TagCriteria]
    order*: SortOrder
    limit*: Natural
    selectedUser*: Option[Id] ## only search notes for a specific user
    skip*: Natural


  AssetItemView* = object
    id*: Id
    name*: Str
    mime*: Str
    size*: Bytes
    active_rels_values*: RelValuesByTagId

  NoteItemView* = object
    id*: Id
    data*: TreeNodeRaw[NativeJson]
    active_rels_values*: RelValuesByTagId

  BoardItemView* = object
    id*: Id
    title*: Str
    screenshot*: Option[Id]
    active_rels_values*: RelValuesByTagId

  LoginForm* = object
    username*: Str
    password*: Str

  Notification* = object
    row_id*: Id
    uid*: Id
    nickname*: Str
    kind*: NotificationKind
    bale_chat_id*: Option[Id]

  GithubCodeEmbed* = object
    style_link*: Str
    html_code*: Str

  LinkPreviewData* = object
    title*: Str
    desc*: Str
    image*: Str


func newNoteData*: TreeNodeRaw[JsonNode] =
  TreeNodeRaw[JsonNode](
    name: "root",
    children: @[],
    data: newJNull())

func hasValue*(tv: TagValueType): bool =
  tv != tvtNone

func hasValue*(t: Tag): bool =
  hasValue t.value_type

func isAdmin*(u: User): bool =
  u.role == urAdmin

func columnName*(vt: TagValueType): string =
  case vt
  of tvtNone: raise newException(ValueError, "'tvtNone' does not have column")
  of tvtFloat: "fval"
  of tvtInt, tvtDate: "ival"
  of tvtJson, tvtStr: "sval"

func isHidden*(lbl: TagLabel): bool =
  lbl in tlForwarded .. tlNotification

func isInfix*(qo: QueryOperator): bool =
  qo in qoLess..qoSubStr

func `[]`*[V](s: seq[V], i: ConnectionPointKind): V =
  assert 2 == len s
  s[ord i]

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
  else: "no operator"

func `$`*(tvt: TagValueType): string =
  case tvt
  of tvtNone: "none"
  of tvtStr: "text"
  of tvtFloat: "float"
  of tvtInt: "int"
  of tvtDate: "date"
  of tvtJson: "JSON"

func `$`*(so: SortOrder): string =
  case so
  of Descending: "DESC"
  of Ascending: "ASC"

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

  proc sqlType*(t: typedesc[SecureHash]): string = "TEXT"
  proc dbValue*(p: SecureHash): DbValue = DbValue(kind: dvkString, s: $p)
  proc to*(src: DbValue, dest: var SecureHash) =
    dest = parseSecureHash src.s

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
    parseHook s, i, temp
    v = cstring temp
