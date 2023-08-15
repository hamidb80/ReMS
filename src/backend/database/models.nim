import std/[options, json, xmltree, xmlparser]
import ponairi
import ../../common/[types]

# TODO add following fields to Assets, Notes, Graph
# uuid
# revision :: for handeling updates
# forked_from :: from uuid
  # nim 2 added Path in std/paths

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
    apBaleBot

  Auth* = object
    id* {.primary, autoIncrement.}: Id
    user* {.references: User.id.}: Id
    platform*: AuthPlatform
    device*: string
    timestamp*: UnixTime

  Asset* = object
    id* {.primary, autoIncrement.}: Id
    owner* {.references: User.id.}: Id
    name*: string
    size*: Bytes
    path*: Path
    timestamp*: UnixTime
    # sha256*: string

  Note* = object
    id* {.primary, autoIncrement.}: Id
    owner* {.references: User.id.}: Id
    data*: JsonNode
    compiled*: XmlNode
    timestamp*: UnixTime

  Board* = object
    id* {.primary, autoIncrement.}: Id
    owner* {.references: User.id.}: Id
    title*: string
    description*: string
    data*: JsonNode
    timestamp*: UnixTime

  Tag* = object
    id* {.primary, autoIncrement.}: Id
    owner* {.references: User.id.}: Id
    name*: string
    has_value*: bool
    is_universal*: bool
    timestamp*: UnixTime

  Relation* = object
    id* {.primary, autoIncrement.}: Id
    by* {.references: User.id.}: Id
    tag* {.references: Tag.id.}: Id
    asset* {.references: Asset.id.}: Option[Id]
    board* {.references: Board.id.}: Option[Id]
    note* {.references: Note.id.}: Option[Id]
    value*: Option[string]
    timestamp*: UnixTime

  RelationsCache* = object
    id* {.primary, autoIncrement.}: Id
    asset* {.references: Asset.id.}: Option[Id]
    board* {.references: Board.id.}: Option[Id]
    note* {.references: Note.id.}: Option[Id]
    tags*: JsonNode # seq of tag

  # TODO Remember, Annonation

# ----- custom types

proc sqlType*(t: typedesc[JsonNode]): string = "TEXT"
proc dbValue*(j: JsonNode): DbValue = DbValue(kind: dvkString, s: $j)
proc to*(src: DbValue, dest: var JsonNode) =
  dest = parseJson src.s

proc sqlType*(t: typedesc[XmlNode]): string = "TEXT"
proc dbValue*(j: XmlNode): DbValue = DbValue(kind: dvkString, s: $j)
proc to*(src: DbValue, dest: var XmlNode) =
  dest = parseXml src.s

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
