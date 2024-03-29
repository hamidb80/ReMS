import std/[macros, uri, strutils, sequtils, tables]
import ../../common/conventions

import macroplus


func safeUrl*(i: SomeNumber or bool): string {.inline.} =
  $i

func safeUrl*(s: string): string {.inline.} =
  encodeUrl s

func safeUrl*(s: seq[int]): string =
  s.join(",")


func parseq*(t: typedesc[seq[int]], s: string): seq[int] =
  if s == "":
    @[]
  else:
    map s.split ',', parseInt

func parseq*(t: typedesc[int], s: string): int =
  parseInt s

func parseq*(t: typedesc[string], s: string): string =
  s


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

func firstArgument(procdef: NimNode): NimNode =
  procdef.params[1][IdentDefName]


func extractQueryParams*(url: string): Table[string, string] =
  let
    qi = url.rfind('?')
    p =
      if qi == -1: ""
      else: url[qi+1 .. ^1]

  for (k, v) in decodeQuery p:
    result[k] = v

func defQueryVar(procdef, q: NimNode): NimNode =
  let req = procdef.firstArgument
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
      let `varIdent` = parseq(`varType`, `q`[`varKey`])

  procdef.body.insert 0, acc
  procdef

macro qparams*(mandatoryArgs, procdef): untyped =
  addQueryParamsImpl procdef, mandatoryArgs

macro qparams*(procdef): untyped =
  addQueryParamsImpl procdef, newStmtList()

macro jbody*(desttype, procdef): untyped =
  let
    req = procdef.firstArgument
    data = ident"data"

  procdef.body.insert 0, quote do:
    let `data` = forceSafety fromJson(`req`.body, `desttype`)

  procdef


macro userOnly*(procdef): untyped =
  let
    req = procdef.firstArgument
    body = procdef.body
    userc = ident"userc"

  procdef.body = quote:
    if tk =? `req`.jwt:
      let verified = forceSafety verify(tk, jwtSecret)
      if verified:
        let
          s = forceSafety tk.claim
          `userc` {.used.} = fromJson($s, UserCache)
        `body`
      else:
        raise newException(ValueError, "Invalid JWT token")
    else:
      raise newException(ValueError, "Not logged in")

  procdef


macro checkAdmin*(procdef): untyped =
  let
    userc = ident"userc"
    body = procdef.body

  procdef.body = quote:
    if `userc`.account.role == urAdmin:
      `body`
    else:
      raise newException(ValueError, "Permission Denied " & $(`userc`.account.role))

  procdef

template respOk*: untyped {.dirty.} =
  req.respond 200

type 
  CacheDecision* = enum
    noCache
    cache

const
  daySecs = 24 * 60 * 60
  longCacheTime* = 30 * daySecs

func cacheTime*(cd: CacheDecision): Natural =
  case cd
  of noCache: 0
  of cache: longCacheTime

template respJson*(body: untyped, cache: CacheDecision = noCache): untyped {.dirty.} =
  req.respond 200, @{
    "Content-Type": "application/json",
    "Cache-Control": "max-age=" & $cacheTime(cache)
    }, body

template respFile*(mime, content: untyped, cache: CacheDecision): untyped {.dirty.} =
  req.respond 200, @{
    "Content-Type": mime,
    "Cache-Control": "max-age=" & $cacheTime(cache)
    }, content

template redirect*(loc: string, cache: CacheDecision = noCache): untyped {.dirty.} =
  req.respond 302, @{
    "Location": loc,
    "Cache-Control": "max-age=" & $cacheTime(cache)}

template respErr*(code, msg): untyped {.dirty.} =
  let ct =
    if "api" in req.uri: "application/json"
    else: "text/html"

  req.respond(code, @{"Content-Type": ct}, msg)

template respErr*(msg): untyped {.dirty.} =
  respErr 400, msg

const OK* = 200

template resp*(code): untyped {.dirty.} =
  req.respond code
