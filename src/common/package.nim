import std/[os, strscans, strutils]

type
    Version = array[3, int]

proc getNimbleVersion: Version =
    let
        content = readFile "./rems.nimble"
        i = content.find("version")

    assert scanf(content[i..^1],
        "version$s=$s\"$i.$i.$i\"",
        result[0],
        result[1],
        result[2])

func `$`(v: Version): string =
    join v, "."


const nimbleVersion* = $getNimbleVersion()

func apv*(path: string): string =
    ## apv :: Attach Package Version
    let parts = splitFile path
    result = parts.dir & '/' & parts.name & '-' & nimbleVersion & parts.ext


echo nimbleVersion
