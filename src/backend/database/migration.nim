# to use for migration

import std/[json, sequtils, os]
import ./[models, dbconn]
import ../config
import ../../common/[types, datastructures]
import ponairi



func fixx(n: sink NoteData): NoteData =
    if n.name == "video":
        let url = getStr n.data
        n.data = %* {
            "url": url,
            "loop": false,
            "width": "",
            "height": ""}
    else:
        for n2 in n.children.mitems:
            n2 = fixx n2
    n

func fixx(n: sink Note): Note =
    n.data = fixx n.data
    n

when isMainModule:
    echo "!!!!!!!!!!!"
    echo appDbPath
    echo fileExists appDbPath

    withConn db:
        let notes =
            find(db, seq[Note], sql"SELECT * FROM Note")
            .mapit(fixx it)

        for n in notes:
            db.exec sql"UPDATE Note SET data = ? WHERE id = ?", n.data, n.id
