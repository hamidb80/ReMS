import std/times
import ponairi
import ./models, ../../common/[path]


type
  AssetUser* = object
    id*: int64
    name*: string
    owner*: int64
    timestamp*: DateTime


template R: untyped {.dirty.} =
  typeof result


proc listAssets*(db: DbConn): seq[AssetUser] =
  db.find(R, sql"SELECT id, name, owner, timestamp FROM Asset ORDER BY id DESC")

proc addAsset*(db: DbConn, n: string, p: Path): int64 =
  db.insertID(Asset(name: n, path: p, timestamp: now()))

proc findAsset*(db: DbConn, id: int64): Asset =
  db.find(R, sql"SELECT * FROM Asset WHERE id=?", id)
