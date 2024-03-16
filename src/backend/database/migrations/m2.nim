import std/[options, sets, strutils]
import ponairi, lowdb
import ../../utils/sqlgen
import ../models
import jsony
include ../jsony_fix

func nuller(v: DbValue): DbValue =
    if v.kind == dvkString and v.s == "":
        dbValue nil
    else:
        v

when isMainModule:
    let
        olddb = newConn "old_db.sqlite3"
        newdb = newConn "db.sqlite3"
        oldrelsq = sql"""
            SELECT 
                /* 0*/ r.id,
                /* 1*/ r.tag,
                /* 2*/ r.kind,
                /* 3*/ r.user,
                /* 4*/ r.asset,
                /* 5*/ r.board,
                /* 6*/ r.node,
                /* 7*/ r.note,
                /* 8*/ r.fval,
                /* 9*/ r.ival,
                /*10*/ r.sval,
                /*11*/ r.refers,
                /*12*/ r.info,
                /*13*/ r.state,
                /*14*/ r.timestamp,
                
                /*15*/ t.id,
                /*16*/ t.owner,
                /*17*/ t.label,
                /*18*/ t.name,
                /*19*/ t.icon,
                /*20*/ t.show_name,
                /*21*/ t.is_private,
                /*22*/ t.can_be_repeated,
                /*23*/ t.theme,
                /*24*/ t.value_type
            FROM 
                Relation r
            JOIN 
                Tag      t
            ON r.tag = t.id
        """


    var
        tagids = initHashset[int]()
        rel_errs: seq[int]

    func str(v: DbValue): string =
        if v.kind == dvkNull: ""
        else: $v

    func `or`(a, b: string): string =
        if a == "": b
        else: a

    for r in rows(olddb, oldrelsq):
        let sval = $r[9] or $r[8] or $r[10]
        let q1 = fsql"""
            INSERT INTO Relation
                   (id    , is_private, user         , asset        , board        , node         , note         ,  refers      , mode, label  , sval  , fval         , info,  state  ,  timestamp)
            VALUES ({r[0]}, 0         , {nuller r[3]}, {nuller r[4]}, {nuller r[5]}, {nuller r[6]}, {nuller r[7]}, {nuller r[8]}, 0   , {r[18]}, {sval}, {nuller r[9]}, ''  ,   {r[13]}, {r[14]}  )
        """

        try:
            exec newdb, q1
        except:
            add rel_errs, r[0].i

        let tid = r[15].i
        if tid notin tagids:
            let q2 = fsql"""
                INSERT INTO Tag
                (owner,   mode, label  , value_type, is_private, icon   , show_name, theme)
                VALUES
                ({r[16]}, 0   , {r[18]}, {r[24]}   , 0         , {r[19]}, 1        , {r[23]})
            """
            incl tagids, tid
            exec newdb, q2

    echo rel_errs

    proc createRelsCache(field: string, rowid: int) =
        var acc: seq[RelMinData]

        for r in newdb.rows fsql"""
            SELECT mode, label, sval, fval
            FROM Relation r
            WHERE r.[field] = {rowid}
        """:
            let v =
                if r[2].kind == dvkNull:
                    if r[3].kind == dvkNull: ""
                    else: $r[3].f
                else: r[2].s

            add acc, RelMinData(
                mode: rmCustom,
                label: r[1].s,
                value: v)

        newdb.exec fsql"""
            INSERT INTO RelsCache
                   ([field], rels)
            VALUES ({rowid}, {toJson acc})  
        """

    for t in ["Asset", "Note", "Board"]:
        for (id, ) in newdb.find(seq[(int, )], fsql"SELECT id FROM [t]"):
            try:
                createRelsCache toLowerAscii t, id
            except:
                echo t, " >> ", id
                echo getCurrentExceptionMsg()
