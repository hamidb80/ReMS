import std/[times, json, options, strutils, strformat, sequtils, tables]

import ponairi
include jsony_fix

import ./models
import ../../common/[types, datastructures]


template R: untyped {.dirty.} =
  typeof result


func initEmptyNote*: Note =
  Note(data: newNoteData())

func sqlize[T](items: seq[T]): string =
  '(' & join(items, ", ") & ')'

func tagIds(data: RelValuesByTagId): seq[Id] =
  data.keys.toseq.mapIt(Id parseInt it)


proc getFirstUser*(db: DbConn): User = 
  db.find R, sql"SELECT * FROM USER"

# TODO add show_name tag
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
  # TODO write a macro called sqlFmt to use {} with sql
  db.exec sql"""UPDATE Tag SET 
      name = ?, 
      value_type = ?, 
      show_name = ?, 
      icon = ?, 
      theme = ?,
      is_private = ?
    WHERE id = ?""",
    t.name,
    t.value_type,
    t.show_name,
    t.icon,
    t.theme,
    t.is_private,
    id

proc deleteTag*(db: DbConn, id: Id) =
  db.exec sql"DELETE FROM Tag WHERE id = ?", id

proc listTags*(db: DbConn): seq[Tag] =
  db.find R, sql"SELECT * FROM Tag"

proc findTags*(db: DbConn, ids: seq[Id]): Table[Id, Tag] =
  for t in db.find(seq[Tag], sql "SELECT * FROM Tag WHERE id IN " & sqlize ids):
    result[t.id] = t

proc addAsset*(db: DbConn, n: string, m: string, p: Path, s: Bytes): int64 =
  db.insertID Asset(
      name: n,
      path: p,
      mime: m,
      size: s)

proc findAsset*(db: DbConn, id: Id): Asset =
  db.find R, sql"SELECT * FROM Asset WHERE id=?", id

proc deleteAsset*(db: DbConn, id: Id) =
  db.exec sql"DELETE FROM Asset WHERE id = ?", id


proc getNote*(db: DbConn, id: Id): NoteItemView =
  db.find R, sql"""
    SELECT n.id, n.data, rc.active_rels_values 
    FROM Note n
    JOIN RelationsCache rc
    ON rc.note = n.id
    WHERE n.id = ?
    """, id

proc newNote*(db: DbConn): Id =
  result = db.insertID initEmptyNote()
  db.insert RelationsCache(note: some result)

proc updateNoteContent*(db: DbConn, id: Id, data: TreeNodeRaw[JsonNode]) =
  db.exec sql"UPDATE Note SET data = ? WHERE id = ?", data, id

# TODO make it generic for notes/assets
proc updateNoteRelTags*(db: DbConn, noteid: Id, data: RelValuesByTagId) =
  transaction db:
    # remove existing rels
    db.exec sql"DELETE FROM Relation WHERE note = ?", noteid
    # remove rel cache
    db.exec sql"DELETE FROM RelationsCache WHERE note = ?", noteid

    # insert new rel cache
    db.insert RelationsCache(
      note: some noteid,
      active_rels_values: data)

    # insert all rels again
    let tags = db.findTags tagIds data
    for key, values in data:
      let
        tagid = Id parseInt key
        t = tags[tagid]

      for v in values:
        var r = Relation(
          note: some noteid,
          tag: tagid,
          #TODO timestamp: now(),
        )

        case t.value_type
        of tvtNone: discard
        of tvtStr, tvtJson:
          r.sval = some v
        of tvtFloat:
          r.fval = some parseFloat v
        of tvtInt, tvtDate:
          r.ival = some parseInt v

        db.insert r

proc deleteNote*(db: DbConn, id: Id) =
  transaction db:
    db.exec sql"DELETE FROM Note WHERE id = ?", id
    db.exec sql"DELETE FROM RelationsCache WHERE note = ?", id
    db.exec sql"DELETE FROM Relation WHERE note = ?", id


proc newBoard*(db: DbConn): Id =
  result = db.insertID Board(
    title: "no title",
    data: BoardData())

  db.insert RelationsCache(
    board: some result,
    active_rels_values: RelValuesByTagId())


proc updateBoard*(db: DbConn, id: Id, data: BoardData) =
  db.exec sql"UPDATE Board SET data = ? WHERE id = ?", data, id

proc setScreenShot*(db: DbConn, boardId, assetId: Id) =
  db.exec sql"UPDATE Board SET screenshot = ? WHERE id = ?", assetId, boardId

proc getBoard*(db: DbConn, id: Id): Board =
  db.find R, sql"SELECT * FROM Board WHERE id = ?", id

proc deleteBoard*(db: DbConn, id: Id) =
  db.exec sql"DELETE FROM Board WHERE id = ?", id


proc getPalette*(db: DbConn, name: string): Palette =
  db.find R, sql"SELECT * FROM Palette WHERE name = ?", name


func toSubQuery(c: TagCriteria, entityIdVar: string): string =
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

    # FIXME security issue when oeprator is qoLike: "LIKE"
    # FIXME not covering "" in string
    primaryCond =
      if isInfix c.operator:
        fmt"rel.{columnName c.valueType} {c.operator} {c.value}"
      else:
        "1"

  fmt""" 
  {introCond} (
    SELECT *
    FROM Relation rel
    WHERE 
        rel.note = {entityIdVar} AND
        {candidateCond} AND
        {primaryCond}
  )
  """

func exploreSqlConds(xqdata: ExploreQuery, ident: string): string =
  if xqdata.criterias.len == 0: "1"
  else:
    xqdata.criterias
    .mapIt(toSubQuery(it, ident))
    .join " AND "

func exploreGenericQuery*(entity: EntityClass, xqdata: ExploreQuery): SqlQuery =
  let repl = exploreSqlConds(xqdata, "thing.id")

  case entity
  of ecNote: sql fmt"""
      SELECT thing.id, thing.data, rc.active_rels_values
      FROM Note thing
      JOIN RelationsCache rc
      ON rc.note = thing.id
      WHERE {repl}
    """

  of ecBoard: sql fmt"""
      SELECT thing.id, thing.title, thing.screenshot, rc.active_rels_values
      FROM Board thing
      JOIN RelationsCache rc
      ON rc.board = thing.id
      WHERE {repl}
    """

  of ecAsset: sql fmt"""
      SELECT thing.id, thing.name, thing.mime, thing.size, rc.active_rels_values
      FROM Asset thing
      JOIN RelationsCache rc
      ON rc.asset = thing.id
      WHERE {repl}
    """

proc exploreNotes*(db: DbConn, xqdata: ExploreQuery): seq[NoteItemView] =
  db.find R, exploreGenericQuery(ecNote, xqdata)

proc exploreBoards*(db: DbConn, xqdata: ExploreQuery): seq[BoardItemView] =
  db.find R, exploreGenericQuery(ecBoard, xqdata)

proc exploreAssets*(db: DbConn, xqdata: ExploreQuery): seq[AssetItemView] =
  db.find R, exploreGenericQuery(ecAsset, xqdata)

proc exploreUser*(db: DbConn, str: string): seq[User] =
  ## FIXME https://stackoverflow.com/questions/3498844/sqlite-string-contains-other-string-query
  db.find R, sql"""
    SELECT *
    FROM User u
    WHERE 
      %?% LIKE u.username OR
      %?% LIKE u.nickname
  """, str, str
