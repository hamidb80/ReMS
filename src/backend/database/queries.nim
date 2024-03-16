## https://stackoverflow.com/questions/3498844/sqlite-string-contains-other-string-query

import std/[times, json, options, strutils, strformat, sequtils, tables]

import ponairi
import questionable
include jsony_fix

import ./[models, logic]
import ../utils/sqlgen
import ../../common/[types, datastructures, conventions]

# ------------------------------------

# proc inspect(s: SqlQuery): SqlQuery =
#   echo "-----------------------"
#   echo s.string
#   s

template tn(tbl): untyped {.dirty.} =
  tableName tbl

template cn(tbl): untyped {.dirty.} =
  columnName tbl


template safeFail(stmt): untyped =
  try: stmt
  except: discard

template `~>`(expr, action): untyped =
  expr.mapIt action


func setRelValue(rel: var Relation, value: string) =
  rel.sval =
    if value == "": none string
    else: some value
  safeFail:
    rel.fval = some parseFloat value

proc getUserAuths*(db: DbConn, user: Id): seq[Auth] =
  db.find R, fsql"""
    SELECT *
    FROM Auth a
    WHERE user = {user}
  """

proc getUserAuth*(db: DbConn, kind: string, user: Id): options.Option[Auth] =
  db.find R, fsql"""
    SELECT *
    FROM Auth a
    WHERE 
      user = {user} AND
      kind = {kind}
  """

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
    else: urUser

  db.insertID User(
    username: uname,
    nickname: nname,
    role: r,
    mode: m)


proc newTag*(db: DbConn, u: User, t: sink Tag) =
  t.owner = u.id
  db.insert t

proc deleteTag*(db: DbConn, u: User, id: Id) =
  db.exec fsql"""
    DELETE FROM Tag 
    WHERE 
      id = {id} AND
      ({isAdmin u} OR owner = {u.id})
  """

proc updateTag*(db: DbConn, u: User, id: Id, t: sink Tag) =
  db.deleteTag u, id
  db.newTag u, t

proc listTagFor*(db: DbConn, u: User): seq[Tag] =
  db.find R, fsql"""
    SELECT * 
    FROM Tag t
    WHERE t.owner = {u.id}
  """

proc allTags*(db: DbConn): seq[Tag] =
  db.find R, sql"SELECT * FROM Tag"

proc addAsset*(db: DbConn, u: User, n: string, m: string, p: Path,
    s: Bytes): int64 =
  result = db.insertID Asset(
      owner: u.id,
      name: n,
      path: p,
      mime: m,
      size: s)

  db.insert RelsCache(
    asset: some result)

proc findAsset*(db: DbConn, id: Id): Asset =
  db.find R, fsql"""
    SELECT * 
    FROM Asset 
    WHERE id = {id}
  """

proc getAsset*(db: DbConn, id: Id): AssetItemView =
  db.find R, fsql"""
    SELECT a.id, a.name, a.mime, a.size, rc.rels
    FROM Asset a
    JOIN RelsCache rc
    ON rc.asset = a.id
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
    SELECT n.id, n.data, rc.rels 
    FROM Note n
    JOIN RelsCache rc
    ON rc.note = n.id
    WHERE n.id = {id}
  """

proc newNote*(db: DbConn, u: User): Id {.gcsafe.} =
  result = forceSafety db.insertID Note(
    owner: u.id,
    data: newNoteData())
  db.insert RelsCache(note: some result)

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

proc deleteRels(
  db: DbConn,
  tab: type,
  id: Id
) =
  db.exec fsql"DELETE FROM Relation  WHERE [cn tab] = {id}"
  db.exec fsql"DELETE FROM RelsCache WHERE [cn tab] = {id}"

template updateRelTagsGeneric*(
  db: DbConn,
  u: User,
  tab: type,
  field: untyped,
  entityId: Id,
  data: seq[RelMinData]
): untyped =
  assert db.hasAccessTo(u, tn tab, entityId)
  transaction db:
    deleteRels db, tab, entityId

    db.insert RelsCache(
      field: some entityId,
      rels: data)

    for t in data:
      var r = Relation(
        field: some entityId,
        label: t.label,
        timestamp: unow())

      setRelValue r, t.value
      db.insert r


proc updateBoardRelTags*(db: DbConn, u: User, id: Id, data: seq[RelMinData]) =
  updateRelTagsGeneric db, u, Board, board, id, data

proc updateAssetRelTags*(db: DbConn, u: User, id: Id, data: seq[RelMinData]) =
  updateRelTagsGeneric db, u, Asset, asset, id, data

proc updateNoteRelTags*(db: DbConn, u: User, id: Id, data: seq[RelMinData]) =
  updateRelTagsGeneric db, u, Note, note, id, data


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
    deleteRels db, table, rowid
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

  db.insert RelsCache(board: some result)

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
      else: "EXISTS"

    candidateCond =
      if m =? c.mode:
        fmt"rel.mode = {ord m}"
      else:
        fmt"rel.label = {dbValue c.label}"

    op =
      if c.operator == qoExists and c.value.len != 0:
        qoEq # exists with a value means equal. ?? (field: 3) -> (field == 3)
      else:
        c.operator

    primaryCond =
      if isInfix op:
        fmt"rel.{columnName c.valueType} {op} {dbvalue c.value}"
      else:
        "1"

  fmt""" 
  {introCond} (
    SELECT *
    FROM Relation rel
    WHERE 
        rel.{entity} = {entityIdVar} AND
        {candidateCond} AND
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
  if sc =? xqdata.sortCriteria and hasValue sc.valueType:
    (
      fmt"""
      JOIN Relation r
      ON 
        r.{entity} = {fieldIdVar} AND
        r.label    = {dbvalue sc.label}
      """,
      fmt"r.{cn sc.valueType}"
    )
  else:
    ("", fieldIdVar)

func exploreGenericQuery*(entity: EntityClass, xqdata: ExploreQuery, offset,
    limit: Natural, user: options.Option[Id]): SqlQuery =
  let
    repl = exploreSqlConds($entity, xqdata, "thing.id")
    (joinq, field) = exploreSqlOrder(entity, "thing.id", xqdata)
    common = fmt"""
      JOIN RelsCache rc
      ON rc.{entity} = thing.id
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
        thing.data, 
        rc.rels
      FROM Note thing
      {common}
    """

  of ecBoard: sql fmt"""
      SELECT 
        thing.id, 
        thing.title, 
        thing.screenshot, 
        rc.rels
      FROM Board thing
      {common}
    """

  of ecAsset: sql fmt"""
      SELECT 
        thing.id, 
        thing.name, 
        thing.mime, 
        thing.size, 
        rc.rels
      FROM Asset thing
      {common}
    """

proc exploreNotes*(db: DbConn, xqdata: ExploreQuery, offset,
    limit: Natural, user: options.Option[Id]): seq[NoteItemView] =
  db.find R, exploreGenericQuery(ecNote, xqdata, offset, limit, user)

proc exploreBoards*(db: DbConn, xqdata: ExploreQuery, offset,
    limit: Natural, user: options.Option[Id]): seq[BoardItemView] =
  db.find R, exploreGenericQuery(ecBoard, xqdata, offset, limit, user)

proc exploreAssets*(db: DbConn, xqdata: ExploreQuery, offset,
    limit: Natural, user: options.Option[Id]): seq[AssetItemView] =
  db.find R, exploreGenericQuery(ecAsset, xqdata, offset, limit, user)

proc exploreUser*(db: DbConn, str: string, offset, limit: Natural): seq[User] =
  db.find R, fsql"""
    SELECT *
    FROM User u
    WHERE 
      instr(u.username, {str}) > 0 OR
      instr(u.nickname, {str}) > 0
  """


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

# proc getActiveNotifs*(db: DbConn): seq[Notification] =
#   db.find R, fsql"""
#     SELECT r.id, u.id, u.nickname, r.kind, a.bale
#     FROM Relation r

#     JOIN User u
#     ON r.user = u.id

#     JOIN Auth a
#     ON a.user = r.user

#     WHERE r.state = {rsFresh}
#     ORDER BY r.id ASC
#   """

proc markNotifsAsStale*(db: DbConn, ids: seq[Id]) =
  db.exec fsql"""
    UPDATE Relation
    SET state = {rsStale}
    WHERE id in [sqlize ids]
  """
