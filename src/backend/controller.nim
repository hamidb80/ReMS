import std/[strformat, options, json, strutils, paths, os, tables, httpclient, uri, times, oids]

import mummy, mummy/multipart, webby/queryparams
import questionable
import ponairi
import bale
import webby
import jsony
import checksums/sha1
import cookiejar
import quickjwt
import pretty
import pkg/htmlparser

import ./[urls, settings]
import ./database/[conn, models, queries]
import ./utils/[web, sqlgen, api_call]
import ../common/[types, path, datastructures, conventions, package]

import ./views/partials

include ./utils/jsony_fix

# ------- Static pages

# TODO add syntax sugar for errors
# TODO define error types

using 
  req: Request

proc notFoundHandler*(req;) =
  respErr 404, "what? " & req.uri

proc errorHandler*(req; e: ref Exception) =
  echo e.msg, "\n\n", e.getStackTrace
  respErr 500, e.msg

proc methodNotAllowedHandle*(req;) = 
  req.respond 200, emptyHttpHeaders(), fmt"{req.httpmethod} :: {req.uri}"


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

  proc(req;) =
    respFile mime, readfile p, cache

proc staticFileHandler*(req;) {.qparams, gcsafe.} =
  let
    fname = q.getOrDefault "file"
    ext   = getExt fname
    mime  = mimeType ext
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

proc isPost(req;): bool = 
  0 == cmpIgnoreCase(req.httpMethod, "POST")

func decodedQuery(body: string): Table[string, string] = 
  for (key, val) in decodeQuery body:
    result[key] = val

# ------- main

proc landingPageHandler*(req;) =
  req.respond 200, emptyHttpHeaders(), landingPageHtml()


## https://community.auth0.com/t/rs256-vs-hs256-jwt-signing-algorithms/58609
const 
  jwtKey* = "auth"
  expireDays = 10

proc appendJwtExpire(ucj: sink JsonNode, expire: int64): JsonNode =
  ucj["exp"] = %expire
  ucj

proc toJwt(uc: UserCache): string =
  sign(
    header = %*{
      "typ": "JWT",
      "alg": "HS256"},
    claim = appendJwtExpire(parseJson toJson uc, toUnix getTime() +
        expireDays.days),
    secret = jwtSecret)

proc jwtCookieSet(token: string): webby.HttpHeaders =
  result["Set-Cookie"] = $initCookie(jwtKey, token, now() + expireDays.days, path = "/")

proc signOutCookieSet*: webby.HttpHeaders =
  result["Set-Cookie"] = $initCookie(jwtKey, "", path = "/")

proc jwt(req;): options.Option[string] =
  try:
    if "Cookie" in req.headers:
      let ck = initCookie req.headers["Cookie"]
      if ck.name == jwtKey:
        return some ck.value
  except:
    discard

proc isSignedIn(req;): options.Option[UserCache] {.nosideeffect, gcsafe.} =
  forceSafety:
    if tk =? `req`.jwt:
      if verify(tk, jwtSecret):
        return some fromJson($tk.claim, UserCache)

proc signinHeaders*(uc: UserCache): webby.HttpHeaders =
  {.cast(gcsafe).}:
    if uc.account.mode != umTest or defined loginTestUser:
      jwtCookieSet toJwt uc
    else:
      raise newException(ValueError, "User is only available at test")

proc signinWithCode(code: string): UserCache =
  let inv = !!<db.findCode(code, unow(), 60)

  # if i =? inv:
  #   let
  #     baleUser  = bale.User i.info
  #     maybeAuth = 
  #     uid =
  #       if a =? maybeAuth: get a.user
  #       else:
  #         let u = !!<db.newUser(
  #           messangerT & "_" & $baleUser.id,
  #           baleUser.firstName & baleUser.lastname.get "",
  #           baleUser.id in adminBaleIds,
  #           umReal)

  #         !!db.activateBaleAuth(i, baleUser.id, u)
  #         u

  #     maybeUsr = !!<db.getUser(uid)

  #   UserCache(account: get maybeUsr)

  # else:
  #   raise newException(ValueError, "invalid code")

proc signinWithForm(username, password: string): UserCache =
  ## sign up with form is not possible, only from bale and enabeling password later
  let
    u = get !!<db.getUser(username)
    p = !!<db.getProfile(u.id, passwordk)

  if $(secureHash password) == p:
    UserCache(account: u)
  else:
    raise newException(ValueError, "password is not valid")

proc signInHandler*(req;) {.gcsafe.} =
  if isPost req:
    let 
      f = decodedQuery req.body
      c = 
        if "form" in f:
          signinWithForm f["username"], f["password"]
        else:
          signinWithCode f["code"]
    
    req.respond 200, signinHeaders c, redirectingHtml u"my-profile"()

  elif uc =? isSignedIn req:
    redirect u"my-profile"()
  else:
    req.respond 200, emptyHttpHeaders(), signInFormHtml()

proc signUpFormHandler*(req;) =
  if isPost req:
    discard
  elif uc =? isSignedIn req:
    redirect u"my-profile"()
  else:
    req.respond 200, emptyHttpHeaders(), signUpFormHtml()

proc myProfileHandler*(req;) =
  if uc =? isSignedIn req:
    redirect u"user-profile"(uc.account.id)
  else:
    redirect u"sign-in"()

proc userProfileHandler*(req;) {.qparams: {id: int}.} =
  let u = !!<db.getUser(id)
  req.respond 200, emptyHttpHeaders(), profileHtml(get u)

proc exploreHandle*(req;) =
  let users =
    !!<db.exploreUser("", 0, 0) 
  req.respond 200, emptyHttpHeaders(), exploreHtml users


proc respHtml*(req; content: string) =
  req.respond 200, emptyHttpHeaders(), content


proc getMe*(req;) {.userOnly.} = 
  respJson toJson userc.account

proc signOutHandler*(req;) =
  req.respond 200, signOutCookieSet(), redirectingHtml u"home"() 


proc getAsset*(req;) {.qparams: {id: int}.} =
  !!respJson toJson db.getAsset(id)

proc updateAssetName*(req;) {.qparams: {id: int, name: string}, userOnly.} =
  !! db.updateAssetName(userc.account, id, name)
  resp OK

proc updateAssetRelTags*(req;) {.qparams: {id: int}, jbody: seq[RelMinData], userOnly.} =
  !! db.updateAssetRelTags(userc.account, id, data)
  resp OK

proc saveAsset(req;): Id {.userOnly.} =
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

proc assetsUpload*(req;) {.userOnly.} =
  respJson str saveAsset req

proc assetShorthand*(req;) =
  let qi = req.uri.find '?'
  if qi == -1:
    notFoundHandler req
  else:
    let assetid = req.uri[qi+1..^1]
    redirect u"download-asset"(parseInt assetid), cache

proc assetsDownload*(req;) {.qparams: {id: int}.} =
  let
    asset = !!<db.findAsset(id)
    content = readfile asset.path

  respFile asset.mime, content, cache

proc deleteAsset*(req;) {.qparams: {id: int}, userOnly.} =
  !!db.deleteAssetLogical(userc.account, id, unow())
  resp OK


proc newNote*(req;) {.userOnly.} =
  let id = forceSafety !!<db.newNote(userc.account)
  redirect note_editor_url id

proc newNoteApi*(req;) {.userOnly.} =
  let id = forceSafety !!<db.newNote(userc.account)
  respJson toJson id

proc getNote*(req;) {.qparams: {id: int}.} =
  !!respJson forceSafety toJson db.getNote(id)

proc getNoteContentQuery*(req;) {.qparams: {id: int, path: seq[int]}.} =
  forceSafety:
    let node = !!<db.getNote(id).data
    respJson toJson node.follow path

proc updateNoteContent*(req;) {.gcsafe, nosideeffect, 
  qparams: {id: int}, 
  jbody: TreeNodeRaw[JsonNode], 
  userOnly
.} =
  forceSafety:
    !!db.updateNoteContent(userc.account, id, data)
    resp OK

proc updateNoteRelTags*(req;) {.qparams: {id: int},
    jbody: seq[RelMinData], userOnly.} =
  !!db.updateNoteRelTags(userc.account, id, data)
  resp OK

proc deleteNote*(req;) {.qparams: {id: int}, userOnly.} =
  !!db.deleteNoteLogical(userc.account, id, unow())
  resp OK


proc newBoard*(req;) {.userOnly.} =
  let id = !!<db.newBoard(userc.account)
  redirect board_editor_url id

proc updateBoardContent*(req;) {.qparams: {id: int}, jbody: BoardData, userOnly.} =
  !!db.updateBoardContent(userc.account, id, data)
  resp OK

proc updateBoardScreenShot*(req;) {.qparams: {id: int}, userOnly.} =
  !!db.setBoardScreenShot(userc.account, id, saveAsset req)
  resp OK

proc updateBoardTitle*(req;) {.qparams: {id: int, title: string}, userOnly.} =
  !!db.updateBoardTitle(userc.account, id, title)
  resp OK

proc updateBoardRelTags*(req;) {.qparams: {id: int},
    jbody: seq[RelMinData], userOnly.} =
  !!db.updateBoardRelTags(userc.account, id, data)
  resp OK

proc getBoard*(req;) {.qparams: {id: int}.} =
  !!respJson toJson db.getBoard(id)

proc deleteBoard*(req;) {.qparams: {id: int}, userOnly.} =
  !!db.deleteBoardLogical(userc.account, id, unow())
  resp OK


proc listTags*(req;) =
  !!respJson toJson db.allTags

proc newTag*(req;) {.jbody: Tag, userOnly.} =
  !!db.newTag(userc.account, data)
  resp OK

proc updateTag*(req;) {.qparams: {id: int}, jbody: Tag, userOnly.} =
  !!db.updateTag(userc.account, id, data)
  resp OK

proc deleteTag*(req;) {.qparams: {id: int}, userOnly.} =
  !!db.deleteTag(userc.account, id)
  resp OK


proc exploreNotes*(req;) {.qparams: {limit: Natural, offset: Natural},
    jbody: ExploreQuery.} =
  !!respJson forceSafety toJson db.exploreNotes(data, offset, limit, none Id)

proc exploreBoards*(req;) {.qparams: {limit: Natural, offset: Natural},
    jbody: ExploreQuery.} =
  !!respJson toJson db.exploreBoards(data, offset, limit, none Id)

proc exploreAssets*(req;) {.qparams: {limit: Natural, offset: Natural},
    jbody: ExploreQuery.} =
  !!respJson toJson db.exploreAssets(data, offset, limit, none Id)

proc exploreUsers*(req;) {.qparams: {name: string, limit: Natural,
    offset: Natural}.} =
  !!respJson toJson db.exploreUser(name, offset, limit)


proc getPalette*(req;) {.qparams: {name: string}.} =
  !!respJson toJson db.getPalette(name).colorThemes

proc updatePalette*(req;) {.qparams: {name: string}, jbody: Palette,
    checkAdmin, userOnly.} =
  !!db.updatePalette(name, data)
  resp OK

proc listPalettes*(req;) =
  !!respJson toJson db.listPalettes()


proc fetchGithubCode*(req;) {.qparams: {url: string}.} =
  respJson toJson parseGithubJsFile download url

proc fetchLinkPreivewData*(req;) {.qparams: {url: string}.} =
  respJson toJson linkPreviewData parseHtml cropHead download url
