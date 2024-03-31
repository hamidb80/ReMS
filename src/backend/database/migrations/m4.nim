import std/[json, sequtils, os, options]

import ponairi

import ../../config
import ../../../common/[datastructures]
import ../[models, dbconn]


func fixx(n: sink NoteData): NoteData =
    let lvl = 
        case n.name
        of "h1": 1
        of "h2": 2
        of "h3": 3
        of "h4": 4
        of "h5": 5
        of "h6": 6
        else:   0 

    case lvl
    of 1..6:
        n.name = "title"
        n.data = %* {
            "priority": lvl}

        debugecho lvl
    
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

    echo "done"