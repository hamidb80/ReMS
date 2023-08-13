import ponairi, waterpark/sqlite # for connection pool

let pool = newSqlitePool(10, "./play.db")

pool.withConnnection db:
  echo db.getRow(sql"wow")