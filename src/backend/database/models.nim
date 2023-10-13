import std/[json, parseutils, algorithm]

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
    ## must be deleted after usage
    id* {.primary, autoIncrement.}: Id
    secret*: Str # TODO hash it
    data*: JsonNode
    timestamp*: UnixTime

  Auth* = object
    ## there are 2 ways of login:
    ## 1. by Bale bot
    ## 2. by username & pass
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
    color_themes*: seq[ColorTheme]

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
    tlFileName         ##
    tlMime             ## mime type of a file

    tlBoardScreenShot  ## screenshots that are taken from boards

    tlTextContent      ## raw text
    tlForwarded        ## a note that is forwarded from another user
    tlNoteHighlight    ##
    tlNoteComment      ## a note (as comment) that refers to main note (ival)
    tlNoteCommentReply ## reply to another comment

    tlPrivate          ## everything is public except when it has private tag
    tlHasAccess        ## tag with username of the person as value - is used with private

    tlLike
    tlImportant
    tlSeeLater

    tlBoardNode
    tlNodeNote         ## note list of node

    tlFollows          ## user => ival (user.id)
    tlNotification     ##

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
    # TODO tag with "open/closed enums" values [only choosing from some options]

  NotificationKind* = enum
    nkLoginBale

  RelationState* = enum
    rsFresh
    rsStale ## to mark as processed or expired by the system

  RelationCreationReason* = enum
    rcrUserInteraction
    rcrSystemAutomation
    rcrExternalEvent

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

    info*: Option[Str]                                ## additional information
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

type # view models
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

  TagKind* = enum
    tkGlobal
    tkUserSpecific

  TagCriteria* = object
    label*: TagLabel
    tagId*: Id
    value_type*: TagValueType
    operator*: QueryOperator
    value*: Str

  ExploreQuery* = object
    searchCriterias*: seq[TagCriteria]
    sortCriteria*: Option[TagCriteria]
    order*: SortOrder
    limit*: Natural
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
    # timestamp*: string # TODO
      # cardType twitter:card


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

func criteriaKind*(tc: TagCriteria): TagKind =
  case tc.label
  of tlOrdinary: tkUserSpecific
  else: tkGlobal

func columnName*(vt: TagValueType): string =
  case vt
  of tvtNone: raise newException(ValueError, "'tvtNone' does not have column")
  of tvtFloat: "fval"
  of tvtInt, tvtDate: "ival"
  of tvtJson, tvtStr: "sval"

func isInfix*(qo: QueryOperator): bool =
  qo in qoLess..qoSubStr

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
  of qoSubStr: "LIKE" # FIXME security issue

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
    parseHook(s, i, temp)
    v = cstring temp
