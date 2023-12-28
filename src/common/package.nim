import std/[os, strscans, strutils]

const nimbleVersion* = block:
    var major, minor, patch: int
    let
        content = readFile "./rems.nimble"
        i = content.find("version")
    assert scanf(content[i..^1], "version$s=$s\"$i.$i.$i\"", major, minor, patch)
    ($major) & '.' & ($minor) & '.' & ($patch)


func distp*(path: string): string = 
  let parts = splitFile path
  result = parts.dir & '/' & parts.name & '-' & nimbleVersion & parts.ext
