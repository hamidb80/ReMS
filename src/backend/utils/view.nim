import std/[macros, tables, uri, strutils, sequtils]
import macroplus


func extractQueryParams*(url: string): Table[string, string] =
  let 
    qi = url.rfind('?')
    s =
      if qi == -1: ""
      else: url[qi+1 .. ^1]

  toTable toseq decodeQuery s
    
macro addQueryParams*(procdef): untyped =
  let
    req = procdef.params[1][IdentDefName]
    q = ident "q"
    def = quote:
      let `q` = extractQueryParams(`req`.uri)

  procdef.body.insert 0, def
  procdef
