import std/[times, json]
import ./models
import ../../common/[types, datastructures]

type
  AssetUser* = object
    id*: Id
    owner*: Id
    name*: Str
    size*: Bytes
    timestamp*: UnixTime

  BoardPreview* = object
    id*: Id
    title*: Str
    description*: Str
    timestamp*: UnixTime


when not defined js:
  import ponairi

  template R: untyped {.dirty.} =
    typeof result


  proc listAssets*(db: DbConn): seq[AssetUser] =
    db.find R, sql"SELECT id, owner, name, size, timestamp FROM Asset ORDER BY id DESC"

  proc addAsset*(db: DbConn, n: string, p: Path, s: Bytes): int64 =
    db.insertID Asset(name: n, path: p, size: s, timestamp: toUnixtime now())

  proc findAsset*(db: DbConn, id: Id): Asset =
    db.find R, sql"SELECT * FROM Asset WHERE id=?", id

  proc deleteAsset*(db: DbConn, id: Id) =
    db.exec sql"DELETE FROM Asset WHERE id = ?", id


  proc listNotes*(db: DbConn): seq[Note] =
    db.find R, sql"SELECT id, owner, data, timestamp FROM Note ORDER BY id DESC"

  proc getNote*(db: DbConn, id: Id): Note =
    db.find R, sql"SELECT id, owner, data, timestamp FROM Note WHERE id = ?", id

  proc newNote*(db: DbConn): Id =
    db.insertID Note(
        data: newNoteData(),
        timestamp: toUnixtime now())

  proc updateNote*(db: DbConn, id: Id, data: TreeNodeRaw[JsonNode]) =
    db.exec sql"UPDATE Note SET data = ? WHERE id = ?", data, id

  proc deleteNote*(db: DbConn, id: Id) =
    db.exec sql"DELETE FROM Note WHERE id = ?", id


  proc newBoard*(db: DbConn): Id =
    db.insertID Board(
      owner: 0,
      title: "no title",
      description: "beta",
      # screenshot: 0,
      data: BoardData(),
      timestamp: toUnixtime now())

  proc updateBoard*(db: DbConn, id: Id, data: BoardData) =
    db.exec sql"UPDATE Board SET data = ? WHERE id = ?", data, id

  proc getBoard*(db: DbConn, id: Id): Board =
    db.find R, sql"SELECT * FROM Board WHERE id = ?", id

  proc listBoards*(db: DbConn): seq[BoardPreview] =
    db.find R, sql"SELECT id, title, description, timestamp FROM Board ORDER by id DESC"

  proc deleteBoard*(db: DbConn, id: Id) =
    db.exec sql"DELETE FROM Board WHERE id = ?", id
