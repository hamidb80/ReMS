# import std/db_sqlite 
import db_connector/db_sqlite
import waterpark/sqlite
import ../config


type DBC* = db_sqlite.DbConn

let pool = newSqlitePool(10, appDbPath)


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
