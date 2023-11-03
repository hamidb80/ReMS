## https://stackoverflow.com/questions/3498844/sqlite-string-contains-other-string-query

import std/[times, json, options, strutils, strformat, sequtils, tables, sha1]
import iterrr

import ponairi
import questionable
include jsony_fix

import ./models
import ../utils/sqlgen
import ../../common/[types, datastructures, conventions]

# TODO add auto generated tags

template R: untyped {.dirty.} =
  typeof result


func initEmptyNote*: Note =
  Note(data: newNoteData())

func sqlize[T](items: seq[T]): string =
  '(' & join(items, ", ") & ')'

func tagIds(data: RelValuesByTagId): seq[Id] =
  data.keys.toseq.mapIt(Id parseInt it)

# ------------------------------------


func setRelValue(rel: var Relation, value_type: TagValueType, value: string) =
  case value_type
  of tvtNone: discard
  of tvtStr, tvtJson:
    rel.sval = some value
  of tvtFloat:
    rel.fval = some parseFloat value
  of tvtInt, tvtDate:
    rel.ival = some parseInt value

template updateRelTagsGeneric*(
  db: DbConn,
  field: untyped,
  fieldStr: string,
  entityId: Id,
  data: RelValuesByTagId
) =
  transaction db:
    # remove existing rels
    db.exec sql "DELETE FROM Relation WHERE " & fieldStr & " = ?", entityId
    # remove rel cache
    db.exec sql "DELETE FROM RelationsCache WHERE " & fieldStr & " = ?", entityId

    # insert new rel cache
    db.insert RelationsCache(
      field: some entityId,
      active_rels_values: data)

    # insert all rels again
    let tags = db.findTags tagIds data
    for key, values in data:
      let
        tagid = Id parseInt key
        t = tags[tagid]

      for v in values:
        var r = Relation(
          field: some entityId,
          tag: tagid,
          #TODO timestamp: now(),
        )

        setRelValue r, t.value_type, v
        db.insert r


proc getInvitation*(db: DbConn, secret: string, time: Unixtime,
    expiresAfterSec: Positive): options.Option[Invitation] =
  db.find R, fsql"""
    SELECT *
    FROM Invitation i 
    WHERE 
      {time} - i.timestamp <= {expiresAfterSec} AND
      secret = {secret}
    """


proc getAuthBale*(db: DbConn, baleUserId: Id): options.Option[Auth] =
  db.find R, fsql"""
    SELECT *
    FROM Auth a
    WHERE bale = {baleUserId}
  """

proc getAuthUser*(db: DbConn, user: Id): options.Option[Auth] =
  db.find R, fsql"""
    SELECT *
    FROM Auth a
    WHERE user = {user}
  """

proc newAuth*(db: DbConn, userId, baleUserId: Id): Id =
  db.insert Auth(
    user: userId,
    bale: some baleUserId)

proc newAuth*(db: DbConn, userId: Id, pass: SecureHash): Id =
  db.insert Auth(
    user: userId,
    hashed_pass: some pass)

proc newInviteCode*(db: DbConn, code: string, info: JsonNode) =
  db.insert Invitation(
      secret: code,
      data: info,
      timestamp: unow())


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

proc newUser*(db: DbConn, uname, nname: string, isAdmin: bool): Id =
  let r =
    if isAdmin: urAdmin
    else: urUser

  db.insertID User(
    username: uname,
    nickname: nname,
    role: r)


proc newTag*(db: DbConn, t: Tag): Id =
  db.insertID Tag(
    owner: 0,
    creator: tcUser,
    label: tlOrdinary,
    can_be_repeated: false,
    show_name: t.show_name,
    is_private: t.is_private,
    theme: t.theme,
    name: t.name,
    icon: t.icon,
    value_type: t.value_type)

proc updateTag*(db: DbConn, id: Id, t: Tag) =
  db.exec fsql"""
    UPDATE Tag SET 
      name = {t.name},
      value_type = {t.value_type},
      show_name = {t.show_name},
      icon = {t.icon},
      theme = {t.theme},
      is_private = {t.is_private}
    WHERE id = {id}
    """

proc deleteTag*(db: DbConn, id: Id) =
  db.exec fsql"DELETE FROM Tag WHERE id = {id}"

proc listTags*(db: DbConn): seq[Tag] =
  db.find R, sql"SELECT * FROM Tag"

proc findTags*(db: DbConn, ids: seq[Id]): Table[Id, Tag] =
  for t in db.find(seq[Tag], fsql"SELECT * FROM Tag WHERE id IN [sqlize ids]"):
    result[t.id] = t


proc addAsset*(db: DbConn, n: string, m: string, p: Path, s: Bytes): int64 =
  result = db.insertID Asset(
      name: n,
      path: p,
      mime: m,
      size: s)

  db.insert RelationsCache(
    asset: some result)

proc findAsset*(db: DbConn, id: Id): Asset =
  db.find R, fsql"SELECT * FROM Asset WHERE id = {id}"

proc getAsset*(db: DbConn, id: Id): AssetItemView =
  db.find R, fsql"""
    SELECT a.id, a.name, a.mime, a.size, rc.active_rels_values
    FROM Asset a
    JOIN RelationsCache rc
    ON rc.asset = a.id
    WHERE a.id = {id}
  """

proc updateAssetName*(db: DbConn, id: Id, name: string) =
  db.exec fsql"""
    UPDATE Asset
    SET name = {name}
    WHERE id = {id}
  """

proc updateAssetRelTags*(db: DbConn, id: Id, data: RelValuesByTagId) =
  updateRelTagsGeneric db, asset, "asset", id, data

proc deleteAssetLogical*(db: DbConn, id: Id, time: UnixTime) =
  db.exec fsql"""
    UPDATE Asset
    SET deleted_at = {time}
    WHERE id = {id}
  """

proc deleteAssetPhysical*(db: DbConn, id: Id) =
  db.exec fsql"DELETE FROM Asset WHERE id = {id}"


proc getNote*(db: DbConn, id: Id): NoteItemView =
  db.find R, fsql"""
    SELECT n.id, n.data, rc.active_rels_values 
    FROM Note n
    JOIN RelationsCache rc
    ON rc.note = n.id
    WHERE n.id = {id}
  """

proc newNote*(db: DbConn): Id {.gcsafe.} =
  result = forceSafety db.insertID initEmptyNote()
  db.insert RelationsCache(note: some result)

proc updateNoteContent*(db: DbConn, id: Id, data: TreeNodeRaw[JsonNode]) =
  db.exec fsql"""
    UPDATE Note 
    SET data = {data},
    WHERE id = {id}
  """

proc updateNoteRelTags*(db: DbConn, noteid: Id, data: RelValuesByTagId) =
  updateRelTagsGeneric db, note, "note", noteid, data

proc deleteNoteLogical*(db: DbConn, id: Id, time: UnixTime) =
  db.exec fsql"""
    UPDATE Note
    SET deleted_at = {time}
    WHERE id = {id}
  """

proc deleteNotePhysical*(db: DbConn, id: Id) =
  transaction db:
    db.exec fsql"DELETE FROM Note           WHERE id   = {id}"
    db.exec fsql"DELETE FROM RelationsCache WHERE note = {id}"
    db.exec fsql"DELETE FROM Relation       WHERE note = {id}"

proc newBoard*(db: DbConn): Id =
  result = db.insertID Board(
    title: "no title",
    data: BoardData())

  db.insert RelationsCache(
    board: some result,
    active_rels_values: RelValuesByTagId())

proc updateBoardContent*(db: DbConn, id: Id, data: BoardData) =
  db.exec fsql"""
    UPDATE Board 
    SET data = {data}
    WHERE id = {id}
  """

proc updateBoardTitle*(db: DbConn, id: Id, title: string) =
  db.exec fsql"""
    UPDATE Board 
    SET title = {title}
    WHERE id = {id}
  """

proc setBoardScreenShot*(db: DbConn, boardId, assetId: Id) =
  db.exec fsql"""
    UPDATE Board 
    SET screenshot = {assetId}
    WHERE id = {boardId}
  """

proc updateBoardRelTags*(db: DbConn, id: Id, data: RelValuesByTagId) =
  updateRelTagsGeneric db, board, "board", id, data

proc getBoard*(db: DbConn, id: Id): Board =
  db.find R, fsql"SELECT * FROM Board WHERE id = {id}"

proc deleteBoardLogical*(db: DbConn, id: Id, time: UnixTime) =
  db.exec fsql"""
    UPDATE Board 
    SET deleted_at = {time}
    WHERE id = {id}
  """

proc deleteBoardPhysical*(db: DbConn, id: Id) =
  db.exec fsql"DELETE FROM Board WHERE id = {id}"

# TODO add pagination
# TODO consider private ones 
func toSubQuery(entity: string, c: TagCriteria, entityIdVar: string): string =
  let
    introCond =
      case c.operator
      of qoNotExists: "NOT EXISTS"
      else: "EXISTS"

    candidateCond =
      case c.label
      of tlOrdinary:
        fmt"rel.tag = {c.tagId}"
      else:
        fmt"rel.label = {c.label.ord}"

    primaryCond =
      if isInfix c.operator:
        fmt"rel.{columnName c.valueType} {c.operator} {dbvalue c.value}"
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
    iterrr items xqdata.searchCriterias:
      map toSubQuery(field, it, ident)
      strjoin " AND "

func exploreSqlOrder(entity: EntityClass, fieldIdVar: string,
    xqdata: ExploreQuery): tuple[joinq, sortIdent: string] =
  if sc =? xqdata.sortCriteria and hasValue sc.valueType:
    (
      fmt"""
      JOIN Relation r
      ON 
        r.{entity} = {fieldIdVar} AND
        r.tag      = {sc.tagId}
      """,
      fmt"r.{columnName sc.valueType}"
    )
  else:
    ("", fieldIdVar)

func exploreGenericQuery*(entity: EntityClass, xqdata: ExploreQuery): SqlQuery =
  let
    repl = exploreSqlConds($entity, xqdata, "thing.id")
    (joinq, field) = exploreSqlOrder(entity, "thing.id", xqdata)
    common = fmt"""
      JOIN RelationsCache rc
      ON rc.{entity} = thing.id
      {joinq}
      WHERE {repl}
      ORDER BY {field} {xqdata.order}"""

  case entity
  of ecNote: sql fmt"""
      SELECT thing.id, thing.data, rc.active_rels_values
      FROM Note thing
      {common}
    """

  of ecBoard: sql fmt"""
      SELECT thing.id, thing.title, thing.screenshot, rc.active_rels_values
      FROM Board thing
      {common}
    """

  of ecAsset: sql fmt"""
      SELECT thing.id, thing.name, thing.mime, thing.size, rc.active_rels_values
      FROM Asset thing
      {common}
    """

proc exploreNotes*(db: DbConn, xqdata: ExploreQuery): seq[NoteItemView] =
  db.find R, exploreGenericQuery(ecNote, xqdata)

proc exploreBoards*(db: DbConn, xqdata: ExploreQuery): seq[BoardItemView] =
  db.find R, exploreGenericQuery(ecBoard, xqdata)

proc exploreAssets*(db: DbConn, xqdata: ExploreQuery): seq[AssetItemView] =
  db.find R, exploreGenericQuery(ecAsset, xqdata)

proc exploreUser*(db: DbConn, str: string): seq[User] =
  db.find R, fsql"""
    SELECT *
    FROM User u
    WHERE 
      instr(u.username, {str}) > 0 OR
      instr(u.nickname, {str}) > 0
  """


proc getPalette*(db: DbConn, name: string): Palette =
  db.find R, fsql"SELECT * FROM Palette WHERE name = {name}"

proc listPalettes*(db: DbConn): seq[Palette] =
  db.find R, sql"SELECT * FROM Palette"

proc updatePalette*(db: DbConn, name: string, p: Palette) =
  db.exec fsql"""
    UPDATE Palette 
    SET color_themes = {p.color_themes}
    WHERE name = {name}
  """

proc loginNotif*(db: DbConn, usr: Id) =
  db.insert Relation(
    user: some usr,
    kind: some ord nkLoginBale,
    timestamp: unow())

proc getActiveNotifs*(db: DbConn): seq[Notification] =
  db.find R, fsql"""
    SELECT r.id, u.id, u.nickname, r.kind, a.bale
    FROM Relation r
    
    JOIN User u
    ON r.user = u.id

    JOIN Auth a
    ON a.user = r.user
    
    WHERE r.state = {rsFresh}
    ORDER BY r.id ASC
  """

proc markNotifsAsStale*(db: DbConn, ids: seq[Id]) =
  db.exec fsql"""
    UPDATE Relation
    SET state = {rsStale}
    WHERE id in [sqlize ids]
  """
