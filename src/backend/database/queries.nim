import std/[times, json, options]
import ./models
import ../../common/[types, datastructures]
import ponairi
include jsony_fix


template R: untyped {.dirty.} =
  typeof result


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


proc listNotes*(db: DbConn): seq[Note] =
  db.find R, sql"SELECT id, data FROM Note ORDER BY id DESC"

proc getNote*(db: DbConn, id: Id): Note =
  db.find R, sql"SELECT id, data FROM Note WHERE id = ?", id

proc newNote*(db: DbConn): Id =
  db.insertID Note(
      data: newNoteData())

proc updateNote*(db: DbConn, id: Id, data: TreeNodeRaw[JsonNode]) =
  db.exec sql"UPDATE Note SET data = ? WHERE id = ?", data, id

proc deleteNote*(db: DbConn, id: Id) =
  db.exec sql"DELETE FROM Note WHERE id = ?", id


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

proc listBoards*(db: DbConn): seq[BoardPreview] =
  db.find R, sql"SELECT id, title, screenshot FROM Board ORDER by id DESC"

proc deleteBoard*(db: DbConn, id: Id) =
  db.exec sql"DELETE FROM Board WHERE id = ?", id


proc newTag*(db: DbConn, t: Tag): Id =
  db.insertID Tag(
    owner: 0,
    creator: tcUser,
    label: tlOrdinary,
    can_repeated: false,
    theme: t.theme,
    name: t.name,
    icon: t.icon,
    value_type: t.value_type)

proc updateTag*(db: DbConn, id: Id, t: Tag) =
  discard

proc deleteTag*(db: DbConn, id: Id) =
  db.exec sql"DELETE FROM Tag WHERE id = ?", id

proc listTags*(db: DbConn): seq[Tag] =
  db.find R, sql"SELECT * FROM Tag ORDER by id DESC"


proc getPalette*(db: DbConn, name: string): Palette =
  db.find R, sql"SELECT * FROM Palette WHERE name = ?", name