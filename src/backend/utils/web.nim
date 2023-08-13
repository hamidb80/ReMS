import std/[macros, strtabs, uri, strutils, sequtils]
import macroplus


func safeUrl*(i: int or float or bool): string {.inline.} = $i
func safeUrl*(s: string): string {.inline.} = encodeUrl s


proc dispatchInfo(entry: NimNode): tuple[
  httpmethod, url, handler: NimNode,
  args, pragmas: seq[NimNode]
] =
  expectKind entry, nnkCommand
  expectLen entry, 3

  result.httpmethod = entry[CommandIdent]
  (result.url, result.args) = block:
    let a1 = entry[CommandArgs[0]]

    case a1.kind
    of nnkStrLit: (a1, @[])
    of nnkInfix:
      assert a1[InfixIdent] == ident"?"
      (a1[1], a1[2][0..^1])
    else:
      raise newException(ValueError, "?")
  (result.handler, result.pragmas) = block:
    let a2 = entry[CommandArgs[1]]
    expectKind a2, nnkPragmaExpr
    (a2[0], a2[1..^1])

  expectKind result.httpmethod, nnkIdent


func toIdentDef(e: NimNode): NimNode =
  expectKind e, nnkExprColonExpr
  newIdentDefs(e[0], e[1])

macro dispatch*(router, body): untyped =
  expectKind body, nnkStmtList
  result = newStmtList()

  for s in body:
    let
      a = dispatchInfo s
      m = a.httpmethod
      h = a.handler
      u = a.url

    if m.strVal == "config":
      let config = ident u.strval.strip(chars = {']', '['}).replace(" ", "") & "Handler"
      result.add quote do:
        when not defined js:
          router.`config` = `h`

    else:
      let
        procname = ident:
          a.httpMethod.strVal &
          a.url.strVal.split("/").join("_") &
          "url"

        procbody = block:
          if a.args.len == 0: newlit u.strVal
          else:
            var patt = u.strVal & "?"

            for i, r in a.args:
              if i != 0:
                patt.add '&'

              let n = r[IdentDefName].strVal
              patt.add n
              patt.add '='
              patt.add '{'
              patt.add "safeUrl "
              patt.add n
              patt.add '}'

            newTree(nnkCommand, ident"fmt", newLit patt)

      result.add newproc(
          exported(procname),
          @[ident"string"] & a.args.map(toIdentDef),
          procbody)

      result.add quote do:
        when not defined js:
          `router`.`m`(`u`, `h`)

  debugEcho repr result


func extractQueryParams*(url: string): StringTableRef =
  result = newStringTable(modeStyleInsensitive)

  let
    qi = url.rfind('?')
    p =
      if qi == -1: ""
      else: url[qi+1 .. ^1]

  for (k, v) in decodeQuery p:
    result[k] = v

macro addQueryParams*(procdef): untyped =
  let
    req = procdef.params[1][IdentDefName]
    q = ident "q"
    def = quote:
      let `q` = extractQueryParams(`req`.uri)

  procdef.body.insert 0, def
  procdef
