import std/[macros, strutils]

import db_connector/db_sqlite


template R*: untyped {.dirty.} =
  typeof result

func sqlize*[T](items: seq[T]): string =
  '(' & join(items, ", ") & ')'

macro fsql*(str: static string): untyped =
    ## strformat for sql
    ## []: raw value
    ## {}: formatted sql, replaced with `?`

    let
        minLen = 2 * len str
        res = genSym(nskVar, "sqlFmtTemp")
    var 
        opened = '.'
        lasti = -1

    result = newStmtList()
    add result, quote do:
        var `res` = newStringOfCap `minLen`

    for i, ch in str:
        case ch
        of '[', '{':
            if opened == '.':
                let d = newLit str[lasti+1 .. i-1]
                opened = ch
                lasti = i
                result.add quote do:
                    `res`.add `d`

        of ']':
            if opened == '[':
                let d = parseExpr str[lasti+1 .. i-1]
                opened = '.'
                lasti = i
                result.add quote do:
                    `res`.add $`d`

        of '}':
            if opened == '{':
                let d = parseExpr str[lasti+1 .. i-1]
                opened = '.'
                lasti = i
                result.add quote do:
                    `res`.add $dbvalue(`d`)

        else:
            discard
    
    let d = str[lasti+1 .. str.len-1]
    result.add quote do:
        `res`.add `d`


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
