import std/[times, json]
import ../../common/[types, datastructures]

type
  AssetUser* = object
    id*: Id
    owner*: Id
    name*: Str
    size*: Bytes
    timestamp*: UnixTime

  NoteObj* = object
    id*: Id
    owner*: Id
    data*: TreeNodeRaw[JsO]
    timestamp*: UnixTime


when not(defined(js) or defined(frontend)):
  import ./models
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


  proc listNotes*(db: DbConn): seq[NoteObj] =
    db.find R, sql"SELECT id, owner, data, timestamp FROM Note ORDER BY id DESC"

  proc getNote*(db: DbConn, id: Id): NoteObj =
    db.find R, sql"SELECT id, owner, data, timestamp FROM Note WHERE id = ?", id

  proc newNote*(db: DbConn): Id =
    db.insertID Note(
        data: newNoteData(),
        timestamp: toUnixtime now())

  proc updateNote*(db: DbConn, id: Id, data: JsonNode) =
    db.exec sql"UPDATE Note SET data = ? WHERE id = ?", data, id

  proc deleteNote*(db: DbConn, id: Id) =
    db.exec sql"DELETE FROM Note WHERE id = ?", id
