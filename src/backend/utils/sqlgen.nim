import std/[macros]

import db_connector/db_sqlite


macro fsql*(str: static string): untyped =
    ## strformat for sql
    ## []: raw value
    ## {}: formatted sql, replaced with `?`

    let 
        minLen = 2 * len str 
        res = genSym(nskVar, "sqlFmtTemp")

    result = newStmtList()
    add result, quote do:
        var `res` = newStringOfCap `minLen`

    var lasti = -1
    for i, ch in str:
        case ch
        of '[', '{':
            let d = newLit str[lasti+1 .. i-1]
            result.add quote do:
                `res`.add `d`

        of ']':
            let d = parseExpr str[lasti+1 .. i-1]
            result.add quote do:
                `res`.add $`d`

        of '}':
            let d = parseExpr str[lasti+1 .. i-1]
            result.add quote do:
                `res`.add $dbvalue(`d`)

        else:
            discard

        case ch
        of '[', ']', '{', '}':
            lasti = i
        else:
            discard

    result = quote:
        block:
            `result`
            sql `res`

    # debugEcho repr result


when isMainModule:
    import lowdb/sqlite
    
    let 
        name = "hamid"
        age = 22

    echo string fsql """
        UPDATE Tag SET 
        name = {name}, 
        age = {age}
        """        
    
    