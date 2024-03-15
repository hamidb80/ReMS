import std/[json, algorithm]

import ../../common/[types, datastructures]

when defined js:
  import ponairi/pragmas
else:
  import ponairi


type # database models
  UserRole* = enum
    urUser
    urAdmin

  UserMode* = enum
    umReal ## real user who signed up 
    umTest ## used for testing

  User* = object
    id* {.primary, autoIncrement.}: Id
    username* {.uniqueIndex.}: Str
    nickname*: Str
    role*: UserRole
    mode*: UserMode

  Auth* = object
    id* {.primary, autoIncrement.}: Id
    kind* {.index.}: string # Email | [third-party-service-name] | ...

    user* {.index, references: User.id.}: Option[Id]
    secret* {.index.}: string

    str_index* {.index.}: string
    int_index* {.index.}: int
    str_val1*: string
    str_val2*: string
    int_val3*: int
    info*: string ## additional information

    created_at*: UnixTime
    activated*: bool

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
    owner* {.references: User.id.}: Option[Id]         ## owner
    name* {.uniqueIndex.}: Str
    color_themes*: seq[ColorTheme]

  RelValueType* = enum
    rvtNone
    rvtStr
    rvtNumber

  RelMode* = enum
    rmCustom           ## user defined

    # -- hidden or special view component
    rmForwarded        ## a note that is forwarded from another user
    rmNoteComment      ## a note (as comment) that refers to main note (refers)
    rmNoteCommentReply ## reply to another comment

    rmBoardNode        ##
    rmBoardNodeNote    ##

    rmFollows          ## user => refers (user.id)
    rmNotification     ##

    # -- visible
    rmOwner            ## owner
    rmTimestamp        ## creation time
    rmSize             ## size in bytes
    rmFileName         ## name of file
    rmMime             ## mime type of a file
    rmPrivate          ## everything is public except when it has private tag

    rmHasAccess        ## tag with username of the person as value - is used with private
    rmNoteHighlight    ##
    rmTextContent      ## raw text
    rmBoardScreenShot  ## screenshots that are taken from boards

    rmLike             ##
    rmImportant        ##
    rmLater            ##

    rmRememberIn       ##
    rmRemembered       ##

  DefinedRel* = object
    id* {.primary, autoIncrement.}: Id
    owner* {.references: User.id.}: Id

    mode* {.index.}: RelMode
    label*: string

    value_type*: RelValueType
    is_private*: bool
    has_value*: bool

    # --- styles
    icon*: Str
    show_name*: bool
    theme*: ColorTheme

  RelationState* = enum
    rsFresh
    rsStale ## to mark as processed or expired by the system

  Relation* = object
    id* {.primary, autoIncrement.}: Id
    is_private*: bool

    user* {.references: User.id.}: Option[Id]         ## owner
    asset* {.references: Asset.id, index.}: Option[Id]
    board* {.references: Board.id, index.}: Option[Id]
    node* {.references: Relation.id, index.}: Option[Id]
    note* {.references: Note.id, index.}: Option[Id]
    refers*: Option[Id]                               ## arbitrary row id

    mode*: RelMode
    label* {.index.}: Str
    sval*: Option[Str]
    fval*: Option[float]

    info*: Str                                        ## additional information
    state*: RelationState
    timestamp*: UnixTime                              ## creation time

  RelMinData* = object
    label*: RelMode
    name*: string
    value*: string

  RelsCache* = object ## one to one relation with Note/Board/Asset
    id* {.primary, autoIncrement.}: Id
    
    user* {.references: User.id.}: Option[Id]
    asset* {.references: Asset.id, index.}: Option[Id]
    board* {.references: Board.id, index.}: Option[Id]
    note* {.references: Note.id, index.}: Option[Id]
    
    rels*: seq[RelMinData]

type # view models
  UserCache* = object
    exp*: int
    account*: User

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
    label*: Option[RelMode]
    tagId*: Id
    value_type*: RelValueType
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
    rels*: seq[RelMinData]

  NoteItemView* = object
    id*: Id
    data*: TreeNodeRaw[NativeJson]
    rels*: seq[RelMinData]

  BoardItemView* = object
    id*: Id
    title*: Str
    screenshot*: Option[Id]
    rels*: seq[RelMinData]

  LoginForm* = object
    username*: Str
    password*: Str

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

func hasValue*(tv: RelValueType): bool =
  tv != rvtNone

func isAdmin*(u: User): bool =
  u.role == urAdmin

func columnName*(vt: RelValueType): string =
  case vt
  of rvtNone: raise newException(ValueError, "'rvtNone' does not have column")
  of rvtNumber: "fval"
  of rvtStr: "sval"

func isHidden*(lbl: RelMode): bool =
  lbl in rmForwarded .. rmNotification

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
  else: raise newException(ValueError, "invalid operator: " & $int(qo))

# func `$`*(tvt: RelValueType): string =
#   case tvt
#   of rvtNone: "none"
#   of rvtStr: "text"
#   of rvtNumber: "float"

func `$`*(so: SortOrder): string =
  case so
  of Descending: "DESC"
  of Ascending: "ASC"

when not defined js:
  import jsony
  include jsony_fix

  template defSqlJsonType(typename): untyped =
    proc sqlType*(t: typedesc[typename]): string = 
      "TEXT"
    
    proc dbValue*(j: typename): DbValue = 
      DbValue(kind: dvkString, s: toJson j)
    
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
    parseHook s, i, temp
    v = cstring temp
