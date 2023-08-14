import std/times
import ponairi
import ./models, ../../common/path


proc listAssets*(db: DbConn): auto =
  db.find(seq[Asset], sql"SELECT * FROM Asset ORDER BY id DESC")

proc addAsset*(db: DbConn, p: Path): int64 =
  db.insertID(Asset(path: p, timestamp: now()))

proc findAsset*(db: DbConn, id: int64): Asset =
  db.find(Asset, sql"SELECT * FROM Asset WHERE id=?", id)
