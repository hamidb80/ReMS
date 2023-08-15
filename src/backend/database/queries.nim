import std/times
import ../../common/types


type
  AssetUser* = object
    id*: Id
    owner*: Id
    name*: Str
    size*: Bytes
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

  proc findAsset*(db: DbConn, id: int64): Asset =
    db.find(R, sql"SELECT * FROM Asset WHERE id=?", id)
