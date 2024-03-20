import ponairi

let db = newConn "db.sqlite3"
db.exec sql"vacuum"