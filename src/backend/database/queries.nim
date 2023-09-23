import std/[times, json, options, strutils, sequtils, tables]

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


proc newTag*(db: DbConn, t: Tag): Id =
  db.insertID Tag(
    owner: 0,
    creator: tcUser,
    label: tlOrdinary,
    can_be_repeated: false,
    theme: t.theme,
    name: t.name,
    icon: t.icon,
    value_type: t.value_type)

proc updateTag*(db: DbConn, id: Id, t: Tag) =
  db.exec sql"""UPDATE Tag SET 
      name = ?, 
      value_type = ?, 
      icon = ?, 
      theme = ?
    WHERE id = ?""",
    t.name,
    t.value_type,
    t.icon,
    t.theme,
    id

proc deleteTag*(db: DbConn, id: Id) =
  db.exec sql"DELETE FROM Tag WHERE id = ?", id

proc listTags*(db: DbConn): seq[Tag] =
  db.find R, sql"SELECT * FROM Tag"

proc findTags*(db: DbConn, ids: seq[Id]): Table[Id, Tag] =
  for t in db.find(seq[Tag], sql "SELECT * FROM Tag WHERE id IN " & sqlize ids):
    result[t.id] = t

proc listAssets*(db: DbConn): seq[AssetItemView] =
  db.find R, sql"SELECT id, name, mime, size FROM Asset ORDER BY id DESC"

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


proc listNotes*(db: DbConn): seq[NoteItemView] =
  db.find R, sql"""
    SELECT n.id, n.data, rc.active_rels_values 
    FROM Note n
    JOIN RelationsCache rc
    ON rc.note = n.id
    ORDER BY n.id DESC"""

proc getNote*(db: DbConn, id: Id): Note =
  db.find R, sql"SELECT id, data FROM Note WHERE id = ?", id

proc newNote*(db: DbConn): Id =
  result = db.insertID initEmptyNote()
  db.insert RelationsCache(note: some result)

proc updateNoteContent*(db: DbConn, id: Id, data: TreeNodeRaw[JsonNode]) =
  db.exec sql"UPDATE Note SET data = ? WHERE id = ?", data, id

# TODO make it generic for notes/assets
proc updateNoteRelTags*(db: DbConn, id: Id, data: RelValuesByTagId) =
  transaction db:
    # remove existing rels
    db.exec sql"DELETE FROM Relation WHERE note = ?", id
    # remove rel cache
    db.exec sql"DELETE FROM RelationsCache WHERE note = ?", id

    # insert new rel cache
    db.insert RelationsCache(
      note: some id,
      active_rels_values: data)
    
    # insert all rels again
    let tags = db.findTags tagIds data
    for key, values in data:
      let
        id = Id parseInt key
        t = tags[id]

      for v in values:
        var r = Relation(
          note: some id,
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
  db.insertID Board(
    title: "no title",
    data: BoardData())

proc updateBoard*(db: DbConn, id: Id, data: BoardData) =
  db.exec sql"UPDATE Board SET data = ? WHERE id = ?", data, id

proc setScreenShot*(db: DbConn, boardId, assetId: Id) =
  db.exec sql"UPDATE Board SET screenshot = ? WHERE id = ?", assetId, boardId

proc getBoard*(db: DbConn, id: Id): Board =
  db.find R, sql"SELECT * FROM Board WHERE id = ?", id

proc listBoards*(db: DbConn): seq[BoardItemView] =
  db.find R, sql"SELECT id, title, screenshot FROM Board ORDER by id DESC"

proc deleteBoard*(db: DbConn, id: Id) =
  db.exec sql"DELETE FROM Board WHERE id = ?", id


proc getPalette*(db: DbConn, name: string): Palette =
  db.find R, sql"SELECT * FROM Palette WHERE name = ?", name
