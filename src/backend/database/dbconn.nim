import waterpark/sqlite
import std/db_sqlite


let pool = newSqlitePool(10, "./play.db")
type DBC* = db_sqlite.DbConn

template withConn*(db, body): untyped =
  pool.withConnnection db:
    body

template `!!`*(dbworks): untyped {.dirty.} =
  withConn db:
    dbworks

template `!!<`*(dbworks): untyped {.dirty.} =
  block:
    proc test(db: DBC): auto =
      dbworks

    var t: typeof test(default DBC)
    withConn db:
      t = dbworks
    t
