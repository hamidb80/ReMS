import std/[times, json, options, strutils, strformat, sequtils, tables, paths]

import ponairi
import questionable
import checksums/sha1

import ./[models, logic]
import ../utils/sqlgen
import ../../common/[types, datastructures, conventions]

include ../utils/jsony_fix


proc inspect(s: SqlQuery): SqlQuery =
  echo "-----------------------"
  echo s.string
  s

template tn(tbl): untyped {.dirty.} =
  tableName tbl

template cn(tbl): untyped {.dirty.} =
  columnName tbl


const
  baleChatIdK* = "bale_chat_id"
  passwordK*   = "password"

proc addAuthCode*(db: DbConn, code: string, info: JsonNode) =
  db.insert AuthCode(
      code: code,
      info: info,
      created_at: unow())

proc findCode*(db: DbConn, code: string, time: Unixtime, expiresAfterSec: Positive): options.Option[AuthCode] =
  db.find R, fsql"""
    SELECT *
    FROM AuthCode ac
    WHERE
      code = {code} AND
      {time} - a.created_at <= {expiresAfterSec}
    """

proc activateBaleAuth*(db: DbConn, userId: Id, baleChatId: int) =
  db.insert Profile(
    user:  userId,
    key:   baleChatIdK,
    value: $baleChatId)

proc addSigninPass*(db: DbConn, userid: Id, password: string) =
  db.insert Profile(
    user:  userid,
    key:   passwordK,
    value: $secureHash password)

proc getUser*(db: DbConn, userid: Id): options.Option[User] =
  db.find R, fsql"""
    SELECT *
    FROM User
    WHERE id = {userid}
  """

proc getUser*(db: DbConn, username: string): options.Option[User] =
  db.find R, fsql"""
    SELECT *
    FROM User u
    WHERE u.username = {username}
  """

proc newUser*(db: DbConn,
  uname, nname: string,
  isAdmin: bool, m: UserMode
): Id =
  let r =
    if isAdmin: urAdmin
    else:       urUser

  db.insertID User(
    username: uname,
    nickname: nname,
    role: r,
    mode: m)


proc getProfile*(db: DbConn, userid: Id, key: string): string =
  let t = 
    db.find( (string,), fsql"""
      SELECT value
      FROM Profile
      WHERE
        user = {userid} AND
        key  = {key}
      LIMIT 1
    """)
  t[0]
  
proc newTagConfig*(db: DbConn, u: User, t: sink TagConfig) =
  t.owner = u.id
  db.insert t

proc deleteTagConfig*(db: DbConn, u: User, id: Id) =
  db.exec fsql"""
    DELETE FROM TagConfig
    WHERE 
      id = {id} AND
      ({isAdmin u} OR owner = {u.id})
  """

proc updateTag*(db: DbConn, u: User, id: Id, t: sink TagConfig) =
  db.deleteTagConfig u, id
  db.newTagConfig u, t

proc listTagsOfUser*(db: DbConn, uid: Id): seq[TagConfig] =
  db.find R, fsql"""
    SELECT * 
    FROM TagConfig t
    WHERE t.owner = {uid}
  """

proc allTags*(db: DbConn): seq[TagConfig] =
  db.find R, sql"SELECT * FROM TagConfig"

proc addAsset*(db: DbConn, u: User, n: string, m: string, p: Path,
    s: Bytes): int64 =
  result = db.insertID Asset(
      owner: u.id,
      name: n,
      path: p,
      mime: m,
      size: s)

proc findAsset*(db: DbConn, id: Id): Asset =
  db.find R, fsql"""
    SELECT * 
    FROM Asset 
    WHERE id = {id}
  """

proc getAsset*(db: DbConn, id: Id): AssetItemView =
  db.find R, fsql"""
    SELECT a.id, a.name, a.mime, a.size
    FROM Asset a
    WHERE a.id = {id}
  """

proc updateAssetName*(db: DbConn, u: User, id: Id, name: string) =
  db.exec fsql"""
    UPDATE Asset
    SET name = {name}
    WHERE 
      id = {id} AND
      ({isAdmin u} OR owner = {u.id})
  """


proc getNote*(db: DbConn, id: Id): NoteItemView =
  db.find R, fsql"""
    SELECT n.id, n.data 
    FROM Note n
    WHERE n.id = {id}
  """

proc newNote*(db: DbConn, u: User): Id {.gcsafe.} =
  forceSafety db.insertID Note(
    owner: u.id,
    data: newNoteData())

proc updateNoteContent*(db: DbConn, u: User, id: Id, data: TreeNodeRaw[JsonNode]) =
  db.exec fsql"""
    UPDATE Note 
    SET data = {data}
    WHERE 
      id = {id} AND
      ({isAdmin u} OR owner = {u.id})
  """


proc hasAccessTo(
  db: DbConn,
  u: User,
  entityTable: string,
  entityId: Id,
): bool =
  1 == len db.find(seq[(int, )], fsql"""
    SELECT 1
    FROM [entityTable] thing
    WHERE 
      thing.id = {entityid} 
      AND (
        {isAdmin(u)} OR 
        thing.owner = {u.id}
      ) 
    LIMIT 1
    """)

proc commonLogicalDelete*(db: DbConn, u: User, table: string, id: Id,
    time: UnixTime) =
  db.exec fsql"""
    UPDATE [table] 
    SET deleted_at = {time}
    WHERE 
      id = {id} AND
      ({isAdmin u} OR owner = {u.id})
  """

proc deleteBoardLogical*(db: DbConn, u: User, id: Id, time: UnixTime) =
  commonLogicalDelete db, u, tn Board, id, time

proc deleteAssetLogical*(db: DbConn, u: User, id: Id, time: UnixTime) =
  commonLogicalDelete db, u, tn Asset, id, time

proc deleteNoteLogical*(db: DbConn, u: User, id: Id, time: UnixTime) =
  commonLogicalDelete db, u, tn Note, id, time


proc deleteCommonPhysical*(db: DbConn, table: type, rowid: Id) =
  transaction db:
    # FIXME tags
    # deleteRels db, table, rowid
    db.exec fsql"""
      DELETE FROM [tn table] 
      WHERE id = {rowid}
    """

proc deleteBoardPhysical*(db: DbConn, id: Id) =
  deleteCommonPhysical db, Board, id

proc deleteAssetPhysical*(db: DbConn, id: Id) =
  deleteCommonPhysical db, Asset, id

proc deleteNotePhysical*(db: DbConn, id: Id) =
  deleteCommonPhysical db, Note, id


proc newBoard*(db: DbConn, u: User): Id =
  result = db.insertID Board(
    title: "[no title]",
    owner: u.id,
    data: BoardData())

proc updateBoardContent*(db: DbConn, u: User, id: Id, data: BoardData) =
  db.exec fsql"""
    UPDATE Board 
    SET data = {data}
    WHERE 
      id = {id} AND
      ({isAdmin u} OR owner = {u.id})
  """

proc updateBoardTitle*(db: DbConn, u: User, id: Id, title: string) =
  db.exec fsql"""
    UPDATE Board 
    SET title = {title}
    WHERE 
      id = {id} AND
      ({isAdmin u} OR owner = {u.id})
  """

proc setBoardScreenShot*(db: DbConn, u: User, boardId, assetId: Id) =
  db.exec fsql"""
    UPDATE Board 
    SET screenshot = {assetId}
    WHERE 
      id = {boardId} AND
      ({isAdmin u} OR owner = {u.id})
  """

proc getBoard*(db: DbConn, id: Id): Board =
  db.find R, fsql"""
    SELECT * 
    FROM Board
    WHERE id = {id}
  """


proc toSubQuery(entity: string, c: TagCriteria, entityIdVar: string): string =
  let
    introCond =
      case c.operator
      of qoNotExists: "NOT EXISTS"
      else:               "EXISTS"

    candidateCond =
      fmt"rel.label = {dbValue c.label}"

    op =
      if c.operator == qoExists and c.value.len != 0:
        qoEq # exists with a value means equal. ?? (field: 3) -> (field == 3)
      else:
        c.operator

    primaryCond =
      if isInfix op:
        fmt"rel.value {op} {dbvalue c.value}"
      else:
        "1"

  fmt""" 
  {introCond} (
    SELECT *
    FROM Tag t
    WHERE 
        t.{entity} = {entityIdVar} AND
        {candidateCond}            AND
        {primaryCond}
  )
  """

func exploreSqlConds(field: string, xqdata: ExploreQuery,
    ident: string): string =
  if xqdata.searchCriterias.len == 0: "1"
  else:
    join xqdata.searchCriterias ~> toSubQuery(field, it, ident), " AND "

func exploreSqlOrder(entity: EntityClass, fieldIdVar: string,
    xqdata: ExploreQuery): tuple[joinq, sortIdent: string] =
  if sc =? xqdata.sortCriteria:
    (
      fmt"""
      JOIN Tag t
      ON 
        t.{entity} = {fieldIdVar} AND
        t.label    = {dbvalue sc.label}
      """,
      "t.value"
    )
  else:
    ("", fieldIdVar)

func exploreGenericQuery*(entity: EntityClass, xqdata: ExploreQuery, offset, limit: Natural, user: options.Option[Id]): SqlQuery =
  let
    repl = exploreSqlConds($entity, xqdata, "thing.id")
    (joinq, field) = exploreSqlOrder(entity, "thing.id", xqdata)
    common = fmt"""
      {joinq}
      WHERE 
        thing.deleted_at IS NULL AND
        NOT thing.is_private AND
        {repl}
        
      ORDER BY {field} {xqdata.order}
      LIMIT {limit}
      OFFSET {offset}
    """

  case entity
  of ecNote: sql fmt"""
      SELECT 
        thing.id, 
        thing.data
      FROM Note thing
      {common}
    """

  of ecBoard: sql fmt"""
      SELECT 
        thing.id, 
        thing.title, 
        thing.screenshot
      FROM Board thing
      {common}
    """

  of ecAsset: sql fmt"""
      SELECT 
        thing.id, 
        thing.name, 
        thing.mime, 
        thing.size
      FROM Asset thing
      {common}
    """

proc exploreUsers*(db: DbConn, str: string, offset, limit: Natural): seq[User] =
  db.find R, fsql"""
    SELECT *
    FROM User u
    WHERE 
      instr(u.username, {str}) > 0 OR
      instr(u.nickname, {str}) > 0
  """

proc exploreNotes*(db: DbConn, xqdata: ExploreQuery, offset, limit: Natural, user: options.Option[Id]): seq[NoteItemView] =
  db.find R, inspect exploreGenericQuery(ecNote, xqdata, offset, limit, user)

proc exploreBoards*(db: DbConn, xqdata: ExploreQuery, offset, limit: Natural, user: options.Option[Id]): seq[BoardItemView] =
  db.find R, exploreGenericQuery(ecBoard, xqdata, offset, limit, user)

proc exploreAssets*(db: DbConn, xqdata: ExploreQuery, offset, limit: Natural, user: options.Option[Id]): seq[AssetItemView] =
  db.find R, exploreGenericQuery(ecAsset, xqdata, offset, limit, user)


proc getPalette*(db: DbConn, name: string): Palette =
  db.find R, fsql"""
    SELECT * 
    FROM Palette 
    WHERE name = {name}
  """

proc listPalettes*(db: DbConn): seq[Palette] =
  db.find R, sql"""
    SELECT * 
    FROM Palette
  """

proc updatePalette*(db: DbConn, name: string, p: Palette) =
  db.exec fsql"""
    UPDATE Palette 
    SET 
      color_themes = {p.color_themes}
    WHERE 
      name = {name}
  """
