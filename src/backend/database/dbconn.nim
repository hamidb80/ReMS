import waterpark/sqlite
import std/db_sqlite

export sqlite.DbConn

let pool = newSqlitePool(10, "./play.db")

template withConn*(db, body): untyped =
  pool.withConnnection db:
    body

template `!!`*(dbworks): untyped {.dirty.} =
  withConn db:
    dbworks

template `!!<`*(dbworks): untyped {.dirty.} =
  block:
    proc test(db: DbConn): auto =
      dbworks

    var t: typeof test(default DbConn)
    withConn db:
      t = dbworks
    t
