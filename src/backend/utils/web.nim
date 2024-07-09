import std/[macros, uri, strutils, sequtils, tables]

import macroplus

import ../../common/[conventions, str]


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


proc dispatchInfo(entry: NimNode): tuple[url: NimNode, args: seq[NimNode]] =
  case entry.kind
  of nnkStrLit: (entry, @[])
  of nnkInfix:  (entry[1], entry[2][0..^1])
  else:         raise newException(ValueError, "?")

func toIdentDef(e: NimNode): NimNode =
  expectKind e, nnkExprColonExpr
  newIdentDefs(e[0], e[1])


func nimFriendly(name: string): string = 
    replaceChar name, '-', '_'

func toUrlVarName(name: string): string = 
    name.nimFriendly & "_raw_url"

func toUrlProcName(name: string): string = 
    name.nimFriendly & "_url"


macro u*(nnode): untyped = 
  ## ident of correspoding var which stores raw url
  ident toUrlProcName strval nnode

macro ur*(nnode): untyped = 
  ## ident of correspoding function which computes url
  ident toUrlVarName  strval nnode

macro defUrl*(nameLit, path): untyped =
  result = newStmtList()

  let
    name           = strval namelit
    dinfo          = dispatchInfo path
    url            = strVal dinfo.url
    procname       = ident toUrlProcName name
    urlVarName     = ident toUrlVarName  name
    procbody       = block:
      if dinfo.args.len == 0: newlit url
      else:
        var patt = url & "?"

        for i, r in dinfo.args:
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

  result.add newConstStmt(exported urlVarName, newlit url)
  result.add newproc(
        exported(procname),
        @[ident"string"] & dinfo.args.map(toIdentDef),
        procbody)

  # debugecho repr result

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
    else:                "text/html"

  req.respond(code, @{"Content-Type": ct}, msg)

template respErr*(msg): untyped {.dirty.} =
  respErr 400, msg

const OK* = 200

template resp*(code): untyped {.dirty.} =
  req.respond code
