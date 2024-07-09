import std/[options, json]

import mummy, mummy/multipart, webby/queryparams
import questionable
import ponairi
import bale
import jsony
import checksums/sha1
import cookiejar
import quickjwt
import htmlparser

import ./[urls, settings]
import ./database/[dbconn, models, queries]
import ./utils/[web, sqlgen, api_call]
import ../common/[types, path, datastructures, conventions, package]

import ./views/partials

include ./database/jsony_fix

# ------- Static pages

# TODO add syntax sugar for errors
# TODO define error types


proc notFoundHandler*(req: Request) =
  respErr 404, "what? " & req.uri

proc errorHandler*(req: Request, e: ref Exception) =
  echo e.msg, "\n\n", e.getStackTrace
  respErr 500, e.msg


func noPathTraversal(s: string): bool =
  ## https://owasp.org/www-community/attacks/Path_Traversal

  for i, ch in s:
    if
      ch == '.' and s[max(i-1, 0)] == '.' or
      ch in {'&', ' ', '~'}:
      return false
  true

proc loadDist*(filename: string): RequestHandler =
  doAssert noPathTraversal filename, "illegal file name"

  let
    p = projectHome / "dist" / apv filename
    mime = mimeType getExt filename

  proc(req: Request) =
    respFile mime, readfile p, cache

proc staticFileHandler*(req: Request) {.qparams, gcsafe.} =
  let
    fname = q.getOrDefault "file"
    ext = getExt fname
    mime = mimeType ext
    fpath = distFolder / fname

  if (fileExists fpath) and (noPathTraversal fname):
    respFile mime, readFile fpath, cache
  else:
    resp 404

# ------- utility

proc download*(url: string): string =
  var client = newHttpClient()
  result = client.get(url).body
  close client

proc isPost(req: Request): bool = 
  0 == cmpIgnoreCase(req.httpMethod, "POST")

func decodedQuery(body: string): Table[string, string] = 
  for (key, val) in decodeQuery body:
    result[key] = val

# ------- main

import pretty

proc landingPageHandler*(req: Request) =
  req.respond 200, emptyHttpHeaders(), landingPageHtml()


proc signInHandler*(req: Request) =
  if isPost req:
    print decodedQuery req.body
    req.respond 200, emptyHttpHeaders(), "wow"
  else:
    req.respond 200, emptyHttpHeaders(), signInFormHtml()

proc signUpFormHandler*(req: Request) =
  req.respond 200, emptyHttpHeaders(), signUpFormHtml()

## https://community.auth0.com/t/rs256-vs-hs256-jwt-signing-algorithms/58609
const jwtKey* = "auth"

proc appendJwtExpire(ucj: sink JsonNode, expire: int64): JsonNode =
  ucj["exp"] = %expire
  ucj

const expireDays = 10

proc toJwt(uc: UserCache): string =
  sign(
    header = %*{
      "typ": "JWT",
      "alg": "HS256"},
    claim = appendJwtExpire(parseJson toJson uc, toUnix getTime() +
        expireDays.days),
    secret = jwtSecret)

proc jwtCookieSet(token: string): HttpHeaders =
  result["Set-Cookie"] = $initCookie(jwtKey, token, now() + expireDays.days, path = "/")

proc jwt*(req: Request): Option[string] =
  try:
    if "Cookie" in req.headers:
      let ck = initCookie req.headers["Cookie"]
      if ck.name == jwtKey:
        return some ck.value
  except:
    discard

proc logoutCookieSet*: HttpHeaders =
  result["Set-Cookie"] = $initCookie(jwtKey, "", path = "/")

proc doLogin*(req: Request, uc: UserCache) =
  if uc.account.mode != umTest or defined loginTestUser:
    {.cast(gcsafe).}:
      respond req, 200, jwtCookieSet toJwt uc
  else:
    raise newException(ValueError, "User is only available at test")

proc loginWithCode(code: string): UserCache =
  let inv = !!<db.getInvitation(code, messangerT, unow(), 60)

  if i =? inv:
    let
      baleUser = bale.User parseJson i.info
      maybeAuth = !!<db.getBaleAuth(baleUser.id)
      uid =
        if a =? maybeAuth: get a.user
        else:
          let u = !!<db.newUser(
            messangerT & "_" & $baleUser.id,
            baleUser.firstName & baleUser.lastname.get "",
            baleUser.id in adminBaleIds,
            umReal)

          !!db.activateBaleAuth(i, baleUser.id, u)
          u

      maybeUsr = !!<db.getUser(uid)

    UserCache(account: get maybeUsr)

  else:
    raise newException(ValueError, "invalid code")

proc loginWithForm(username, password: string): UserCache =
  ## sign up with form is not possible, only from bale and enabeling password later
  let
    u = get !!<db.getUser(lf.username)
    a = get !!<db.getUserAuth(userPassT, u.id)

  if $(secureHash lf.password) == a.secret:
    UserCache(account: u)
  else:
    raise newException(ValueError, "password is not valid")

proc myProfileHandler*(req: Request) =
  redirect u"sign-in"()



proc respHtml*(req: Request, content: string) =
  req.respond 200, emptyHttpHeaders(), content


proc getMe*(req: Request) {.userOnly.} =
  respJson toJson userc.account

proc logout*(req: Request) =
  respond req, 200, logoutCookieSet()


proc getAsset*(req: Request) {.qparams: {id: int}.} =
  !!respJson toJson db.getAsset(id)

proc updateAssetName*(req: Request) {.qparams: {id: int, name: string}, userOnly.} =
  !! db.updateAssetName(userc.account, id, name)
  resp OK

proc updateAssetRelTags*(req: Request) {.qparams: {id: int}, jbody: seq[
    RelMinData], userOnly.} =
  !! db.updateAssetRelTags(userc.account, id, data)
  resp OK

proc saveAsset(req: Request): Id {.userOnly.} =
  let multip = req.decodeMultipart()

  for entry in multip:
    if entry.data.isSome:
      let
        (start, last)  = entry.data.get
        content        = req.body[start..last]
        (_, name, ext) = splitFile entry.filename.get
        fname          = name & ext
        mime           = mimetype ext
        oid            = genOid()
        timestamp      = toUnix getTime()

      {.cast(gcsafe).}:
        let storePath = appSaveDir / fmt"{oid}-{timestamp}{ext}"
        writeFile storePath, content
        return !!<db.addAsset(
            userc.account,
            fname,
            mime,
            Path storePath,
            Bytes len start..last)

  raise newException(ValueError, "no files found")

proc assetsUpload*(req: Request) {.userOnly.} =
  respJson str saveAsset req

proc assetShorthand*(req: Request) =
  let qi = req.uri.find '?'
  if qi == -1:
    notFoundHandler req
  else:
    let assetid = req.uri[qi+1..^1]
    redirect u"download-asset"(parseInt assetid), cache

proc assetsDownload*(req: Request) {.qparams: {id: int}.} =
  let
    asset = !!<db.findAsset(id)
    content = readfile asset.path

  respFile asset.mime, content, cache

proc deleteAsset*(req: Request) {.qparams: {id: int}, userOnly.} =
  !!db.deleteAssetLogical(userc.account, id, unow())
  resp OK


proc newNote*(req: Request) {.userOnly.} =
  let id = forceSafety !!<db.newNote(userc.account)
  redirect note_editor_url id

proc newNoteApi*(req: Request) {.userOnly.} =
  let id = forceSafety !!<db.newNote(userc.account)
  respJson toJson id

proc getNote*(req: Request) {.qparams: {id: int}.} =
  !!respJson forceSafety toJson db.getNote(id)

proc getNoteContentQuery*(req: Request) {.qparams: {id: int, path: seq[int]}.} =
  forceSafety:
    let node = !!<db.getNote(id).data
    respJson toJson node.follow path

proc updateNoteContent*(req: Request) {.gcsafe, nosideeffect, qparams: {
    id: int}, jbody: TreeNodeRaw[JsonNode], userOnly.} =

  forceSafety:
    !!db.updateNoteContent(userc.account, id, data)
    resp OK

proc updateNoteRelTags*(req: Request) {.qparams: {id: int},
    jbody: seq[RelMinData], userOnly.} =
  !!db.updateNoteRelTags(userc.account, id, data)
  resp OK

proc deleteNote*(req: Request) {.qparams: {id: int}, userOnly.} =
  !!db.deleteNoteLogical(userc.account, id, unow())
  resp OK


proc newBoard*(req: Request) {.userOnly.} =
  let id = !!<db.newBoard(userc.account)
  redirect board_editor_url id

proc updateBoardContent*(req: Request) {.qparams: {id: int}, jbody: BoardData, userOnly.} =
  !!db.updateBoardContent(userc.account, id, data)
  resp OK

proc updateBoardScreenShot*(req: Request) {.qparams: {id: int}, userOnly.} =
  !!db.setBoardScreenShot(userc.account, id, saveAsset req)
  resp OK

proc updateBoardTitle*(req: Request) {.qparams: {id: int, title: string}, userOnly.} =
  !!db.updateBoardTitle(userc.account, id, title)
  resp OK

proc updateBoardRelTags*(req: Request) {.qparams: {id: int},
    jbody: seq[RelMinData], userOnly.} =
  !!db.updateBoardRelTags(userc.account, id, data)
  resp OK

proc getBoard*(req: Request) {.qparams: {id: int}.} =
  !!respJson toJson db.getBoard(id)

proc deleteBoard*(req: Request) {.qparams: {id: int}, userOnly.} =
  !!db.deleteBoardLogical(userc.account, id, unow())
  resp OK


proc listTags*(req: Request) =
  !!respJson toJson db.allTags

proc newTag*(req: Request) {.jbody: Tag, userOnly.} =
  !!db.newTag(userc.account, data)
  resp OK

proc updateTag*(req: Request) {.qparams: {id: int}, jbody: Tag, userOnly.} =
  !!db.updateTag(userc.account, id, data)
  resp OK

proc deleteTag*(req: Request) {.qparams: {id: int}, userOnly.} =
  !!db.deleteTag(userc.account, id)
  resp OK


proc exploreNotes*(req: Request) {.qparams: {limit: Natural, offset: Natural},
    jbody: ExploreQuery.} =
  !!respJson forceSafety toJson db.exploreNotes(data, offset, limit, none Id)

proc exploreBoards*(req: Request) {.qparams: {limit: Natural, offset: Natural},
    jbody: ExploreQuery.} =
  !!respJson toJson db.exploreBoards(data, offset, limit, none Id)

proc exploreAssets*(req: Request) {.qparams: {limit: Natural, offset: Natural},
    jbody: ExploreQuery.} =
  !!respJson toJson db.exploreAssets(data, offset, limit, none Id)

proc exploreUsers*(req: Request) {.qparams: {name: string, limit: Natural,
    offset: Natural}.} =
  !!respJson toJson db.exploreUser(name, offset, limit)


proc getPalette*(req: Request) {.qparams: {name: string}.} =
  !!respJson toJson db.getPalette(name).colorThemes

proc updatePalette*(req: Request) {.qparams: {name: string}, jbody: Palette,
    checkAdmin, userOnly.} =
  !!db.updatePalette(name, data)
  resp OK

proc listPalettes*(req: Request) =
  !!respJson toJson db.listPalettes()


proc fetchGithubCode*(req: Request) {.qparams: {url: string}.} =
  respJson toJson parseGithubJsFile download url

proc fetchLinkPreivewData*(req: Request) {.qparams: {url: string}.} =
  respJson toJson linkPreviewData parseHtml cropHead download url
