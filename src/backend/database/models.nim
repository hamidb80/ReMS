import std/[options, times, json, xmltree, xmlparser]
import ponairi # sqlite

import ../../common/path

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
    id* {.primary, autoIncrement.}: int64
    username* {.index.}: string
    nickname*: string
    role*: UserRole

  AuthPlatform* = enum
    apBaleBot

  Auth* = object
    id* {.primary, autoIncrement.}: int64
    user* {.references: User.id.}: int64
    platform*: AuthPlatform
    device*: string
    timestamp*: DateTime

  Asset* = object
    id* {.primary, autoIncrement.}: int64
    owner* {.references: User.id.}: int64
    name*: string
    # sha256*: string
    path*: Path
    timestamp*: DateTime

  Note* = object
    id* {.primary, autoIncrement.}: int64
    owner* {.references: User.id.}: int64
    data*: JsonNode
    compiled*: XmlNode
    timestamp*: DateTime

  Board* = object
    id* {.primary, autoIncrement.}: int64
    owner* {.references: User.id.}: int64
    title*: string
    description*: string
    data*: JsonNode
    timestamp*: DateTime

  Tag* = object
    id* {.primary, autoIncrement.}: int64
    creator* {.references: User.id.}: int64
    name*: string
    has_value*: bool
    is_universal*: bool
    timestamp*: DateTime

  Relation* = object
    id* {.primary, autoIncrement.}: int64
    by* {.references: User.id.}: int64
    tag* {.references: Tag.id.}: int64
    asset* {.references: Asset.id.}: Option[int64]
    board* {.references: Board.id.}: Option[int64]
    note* {.references: Note.id.}: Option[int64]
    value*: Option[string]
    timestamp*: DateTime

  RelationsCache* = object
    id* {.primary, autoIncrement.}: int64
    asset* {.references: Asset.id.}: Option[int64]
    board* {.references: Board.id.}: Option[int64]
    note* {.references: Note.id.}: Option[int64]
    tags*: JsonNode

  # TODO Remember

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

func `%`*(p: Path): JsonNode = %p.string
func `%`*(d: DateTime): JsonNode = %d.toTime.toUnix

# ----- basic operations

proc createTables*(db: DbConn) =
  db.create(User, Auth, Asset, Note, Board, Tag, Relation, RelationsCache)
