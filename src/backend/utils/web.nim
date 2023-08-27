import std/[macros, uri, strutils, sequtils, strtabs]
import macroplus


func safeUrl*(i: SomeNumber or bool): string {.inline.} = $i
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

macro dispatch*(router, viewModule, body): untyped =
  expectKind body, nnkStmtList
  var
    urls = newStmtList()
    rout = newStmtList()

  for s in body:
    let
      a = dispatchInfo s
      m = a.httpmethod
      h = a.handler
      u = a.url

    if m.strVal == "config":
      let config = ident u.strval.strip(chars = {']', '['}).replace(" ", "") & "Handler"
      rout.add quote do:
        router.`config` = `h`

    else:
      let
        normalizedName = a.url.strVal.replace("-", "/").split("/").join("_")
        # absPage = ident normalizedName.strip('_') & "_page_url"
        url = u.strVal
        procname = ident a.httpMethod.strVal & normalizedName & "url"

        procbody = block:
          if a.args.len == 0: newlit url
          else:
            var patt = url & "?"

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

      urls.add newproc(
          exported(procname),
          @[ident"string"] & a.args.map(toIdentDef),
          procbody)

      # urls.add newConstStmt(exported absPage, u)
      rout.add quote do:
        `router`.`m`(`u`, `h`)

  result = quote:
    `urls`
    when not (defined(js) or defined(frontend)):
      import `viewModule`
      `rout`
  # debugEcho repr result


func extractQueryParams*(url: string): StringTableRef =
  result = newStringTable(modeStyleInsensitive)

  let
    qi = url.rfind('?')
    p =
      if qi == -1: ""
      else: url[qi+1 .. ^1]

  for (k, v) in decodeQuery p:
    result[k] = v

func defQueryVar(procdef, q: NimNode): NimNode =
  let req = procdef.params[1][IdentDefName]
  quote:
    let `q` = extractQueryParams(`req`.uri)

proc addQueryParamsImpl(procDef, mandatoryArgs: NimNode): NimNode =
  let q = ident "q"
  var acc = newStmtList()
  acc.add defQueryVar(procdef, q)

  for a in mandatoryArgs:
    let
      varIdent = a[0]
      varKey = newLit a[0].strVal
      varType = a[1]
    acc.add quote do:
      let `varIdent` = parse(`varType`, `q`[`varKey`])

  procdef.body.insert 0, acc
  procdef

macro addQueryParams*(mandatoryArgs, procdef): untyped =
  debugEcho treeRepr mandatoryArgs
  addQueryParamsImpl procdef, mandatoryArgs

macro addQueryParams*(procdef): untyped =
  addQueryParamsImpl procdef, newStmtList()


template respJson*(body): untyped {.dirty.} =
  req.respond 200, @{"Content-Type": "application/json"}, body

template respOk*: untyped {.dirty.} =
  req.respond 200


template parse*(t: typedesc[int], s: string): int =
  parseInt s
  
template parse*(t: typedesc[string], s: string): string =
  s