import std/[algorithm, json]

import ../../common/[types, datastructures]

when defined js:
  import ponairi/pragmas
else:
  import ponairi


type 
  # ------------ database models ------------
  
  UserRole* = enum
    urUser
    urAdmin

  UserMode* = enum
    umReal ## real user who signed up
    umTest ## used for testing

  User* = object
    ## minimum info about a user
    id* {.primary, autoIncrement.}: Id
    username* {.uniqueIndex.}:      Str
    nickname*:                      Str
    role*:                          UserRole
    mode*:                          UserMode

  Profile* = object
    ## key value facts about a user
    id* {.primary, autoIncrement.}:       Id
    user* {.index, references: User.id.}: Id
    key*:                                 Str
    value*:                               Str

  AuthCode* = object
    id*   {.primary, autoIncrement.}:  Id
    code* {.index.}:                   Str
    created_at*:                       UnixTime

  Asset* = object
    id*  {.primary, autoIncrement.}: Id
    name*:                           Str  # name with extention
    mime*:                           Str
    size*:                           Bytes
    path*:                           Path # where is it stored?

    owner* {.references: User.id.}:  Id
    is_private*:                     bool
    deleted_at*:                     Option[UnixTime]

  Note* = object
    id* {.primary, autoIncrement.}: Id
    data*:                          NoteData

    owner* {.references: User.id.}: Id
    is_private*:                    bool
    deleted_at*:                    Option[UnixTime]

  Board* = object
    id* {.primary, autoIncrement.}:       Id
    title*:                               Str
    screenshot* {.references: Asset.id.}: Option[Id]
    data*:                                BoardData

    owner* {.references: User.id.}: Id
    is_private*: bool
    deleted_at*: Option[UnixTime]

  Palette* = object
    id*    {.primary, autoIncrement.}: Id
    owner* {.references: User.id.}:    Option[Id]         ## owner
    name*  {.uniqueIndex.}:            Str
    color_themes*:                     seq[ColorTheme]

  Tag* = object ## Relation Template
    id* {.primary, autoIncrement.}: Id
    owner* {.references: User.id.}: Id

    mode* {.index.}: RelMode
    label*: Str

    value_type*: RelValueType
    is_private*: bool
  
    # --- styles
    icon*: Str
    show_name*: bool
    theme*: ColorTheme

  RelValueType* = enum
    rvtNone
    rvtStr
    rvtFloat
    rvtInt
    rvtDate

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

  RelState* = enum
    rsFresh
    rsStale ## to mark as processed or expired by the system

  Relation* = object
    id* {.primary, autoIncrement.}: Id
    is_private*: bool

    user*  {.references: User.id.}:            Option[Id]  ## owner
    asset* {.references: Asset.id,    index.}: Option[Id]
    board* {.references: Board.id,    index.}: Option[Id]
    node*  {.references: Relation.id, index.}: Option[Id]
    note*  {.references: Note.id,     index.}: Option[Id]
    refers*:                                   Option[Id] ## arbitrary row id

    label* {.index.}: Str
    mode*:            RelMode
    
    sval*: Option[Str]
    fval*: Option[float]
    ival*: Option[int]

    info*:      Str                                  ## additional information
    state*:     RelState
    timestamp*: UnixTime                             ## creation time

  RelsCache* = object ## one to one relation with Note/Board/Asset
    id* {.primary, autoIncrement.}: Id

    user*  {.references: User.id.}:         Option[Id]
    asset* {.references: Asset.id, index.}: Option[Id]
    board* {.references: Board.id, index.}: Option[Id]
    note*  {.references: Note.id,  index.}: Option[Id]

    rels*: seq[RelMinData]

  RelMinData* = object ## minimum relation data
    mode*:  RelMode
    label*: Str
    value*: Str

  # ------------ view models ------------

  UserCache* = object
    exp*:     int
    account*: User

  EntityClass* = enum
    ecNote  = "note"
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
    mode*:       Option[RelMode]
    label*:      Str
    value_type*: RelValueType
    operator*:   QueryOperator
    value*:      Str

  ExploreQuery* = object
    searchCriterias*: seq[TagCriteria]
    sortCriteria*:    Option[TagCriteria]
    order*:           SortOrder
    limit*:           Natural
    selectedUser*:    Option[Id] ## only search notes for a specific user
    skip*:            Natural


  AssetItemView* = object
    id*:   Id
    name*: Str
    mime*: Str
    size*: Bytes
    rels*: seq[RelMinData]

  NoteItemView* = object
    id*:   Id
    data*: TreeNodeRaw[NativeJson]
    rels*: seq[RelMinData]

  BoardItemView* = object
    id*:         Id
    title*:      Str
    screenshot*: Option[Id]
    rels*:       seq[RelMinData]

  LoginForm* = object
    username*: Str
    password*: Str

  GithubCodeEmbed* = object
    style_link*: Str
    html_code*:  Str

  LinkPreviewData* = object
    title*: Str
    desc*:  Str
    image*: Str


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
  defSqlJsonType RelMinData
  defSqlJsonType seq[RelMinData]

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
