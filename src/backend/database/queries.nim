import std/[times, json]
import ../../common/types


type
  AssetUser* = object
    id*: Id
    owner*: Id
    name*: Str
    size*: Bytes
    timestamp*: UnixTime

  NotePreview* = object
    id*: Id
    owner*: Id
    preview*: JsO
    timestamp*: UnixTime

  NoteFull* = object
    id*: Id
    owner*: Id
    data*: JsO
    timestamp*: UnixTime


when not(defined(js) or defined(frontend)):
  import ponairi
  import ./models


  template R: untyped {.dirty.} =
    typeof result


  proc listAssets*(db: DbConn): seq[AssetUser] =
    db.find(R, sql"SELECT id, owner, name, size, timestamp FROM Asset ORDER BY id DESC")

  proc addAsset*(db: DbConn, n: string, p: Path, s: Bytes): int64 =
    db.insertID(Asset(name: n, path: p, size: s, timestamp: toUnixtime now()))

  proc findAsset*(db: DbConn, id: Id): Asset =
    db.find(R, sql"SELECT * FROM Asset WHERE id=?", id)


  proc listNotes*(db: DbConn): seq[NotePreview] =
    db.find(R, sql"SELECT id, owner, preview, timestamp FROM Note ORDER BY id DESC")

  proc getNote*(db: DbConn, id: Id): NoteFull =
    db.find(R, sql"SELECT id, owner, data, timestamp FROM Note WHERE id = ?", id)

  proc newNote*(db: DbConn): Id =
    db.insertID(Note(
        data: newJNull(),
        preview: newJNull(),
        timestamp: toUnixtime now()))
