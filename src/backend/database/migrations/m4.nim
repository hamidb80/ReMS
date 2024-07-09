import std/[json, sequtils, os, options]

import htmlparser
import ponairi

import ../../settings
import ../../../common/[datastructures]
import ../[models, dbconn]

import std/httpclient
import ../../utils/api_call

let c = newHttpclient()

proc fixx(n: sink NoteData): NoteData =
    case n.name
    of "link preview":
        let url = getstr n.data["url"]
        echo ">> ", url

        let d = 
            try:
                linkPreviewData parseHtml cropHead c.getContent url
            except:
                LinkPreviewData(
                    title: url,
                    desc: "",
                    image: "")

        n.data = %* {
            "url": url,
            "title": d.title,
            "desc": d.desc,
            "image": d.image,
            }

    else:
        for n2 in n.children.mitems:
            n2 = fixx n2
    n

proc fixx(n: sink Note): Note =
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
