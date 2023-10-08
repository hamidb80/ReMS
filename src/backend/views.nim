## https://community.auth0.com/t/rs256-vs-hs256-jwt-signing-algorithms/58609

import std/[strformat, tables, strutils, os, oids, json, httpclient, sha1,
    times, htmlparser]

import mummy, mummy/multipart
import webby
import quickjwt
import cookiejar
import jsony
import questionable
import bale

import ../common/[types, path, datastructures, conventions]
import ./utils/[web, github, link_preview]
import ./routes
import ./database/[models, queries, dbconn]

include ./database/jsony_fix


# ------- Static pages

proc notFoundHandler*(req: Request) =
  respErr 404, "what? " & req.uri

proc errorHandler*(req: Request, e: ref Exception) =
  echo e.msg, "\n\n", e.getStackTrace
  respErr 500, e.msg

proc staticFileHandler*(req: Request) {.qparams.} =
  if "file" in q:
    let
      fname = q["file"]
      ext = getExt fname
      mime = mimeType ext
      fpath = projectHome / "dist" / fname

    if fileExists fpath:
      respFile mime, readFile fpath

    else: resp 404
  else: resp 404

proc loadDist*(path: string): RequestHandler =
  let
    p = projectHome / "dist" / path
    mime = mimeType getExt path

  proc(req: Request) =
    respFile mime, readfile p

# ------- Dynamic ones

proc download*(url: string): string =
  var client = newHttpClient()
  client.get(url).body

const jwtKey = "auth"
let jwtSecret = "TODO" # getEnv "JWT_KEY"

proc toUserJwt(u: models.User, expire: int64): JsonNode =
  %*{
    "exp": expire,
    "user": {
      "id": u.id,
      "username": u.username,
      "nickname": u.nickname,
      "role": u.role.ord}}

proc toJwt(u: models.User): string =
  sign(
    header = %*{
      "typ": "JWT",
      "alg": "HS256"},
    claim = toUserJwt(u, toUnix getTime() + 1.days),
    secret = jwtSecret)

proc jwtCookieSet(token: string): webby.HttpHeaders =
  result["Set-Cookie"] = $initCookie(jwtKey, token, now() + 30.days, path = "/")

proc logoutCookieSet: webby.HttpHeaders =
  result["Set-Cookie"] = $initCookie(jwtKey, "", path = "/")

proc login*(req: Request, u: models.User) =
  {.cast(gcsafe).}:
    respond req, 200, jwtCookieSet toJwt u

proc logout*(req: Request) =
  respond req, 200, logoutCookieSet()

proc jwt(req: Request): options.Option[string] =
  try:
    if "Cookie" in req.headers:
      let ck = initCookie req.headers["Cookie"]
      if ck.name == jwtKey:
        return some ck.value
  except:
    discard

proc getMe*(req: Request) {.adminOnly.} =
  respJson toJson user

proc loginWithInvitationCode*(req: Request) {.qparams: {secret: string}.} =
  let inv = !!<db.getInvitation(secret, toUnixTime now(), 60)

  if i =? inv:
    let
      baleUser = bale.User i.data
      maybeAuth = !!<db.getAuthBale(baleUser.id)
      uid =
        if a =? maybeAuth: a.user
        else:
          let u = !!<db.newUser(
            "bale_" & $baleUser.id,
            baleUser.firstName & baleUser.lastname.get "")
          discard !!<db.newAuth(u, baleUser.id)
          u

      maybeUsr = !!<db.getUser(uid)

    login req, get maybeUsr
    !!db.loginNotif(uid)


  else:
    resp 404

proc loginWithForm*(req: Request) {.jbody: LoginForm.} =
  let
    u = get !!<db.getUser(data.username)
    a = get !!<db.getAuthUser(u.id)

  if hash =? a.hashedPass:
    if hash == secureHash data.password:
      login req, u
    else:
      raise newException(ValueError, "password is not valid")
  else:
    raise newException(ValueError, "the user does not set login with password")

proc signupWithForm*(req: Request) {.jbody: LoginForm.} =
  let
    u = !!<db.newUser(data.username, data.username)
    a = !!<db.newAuth(u, secureHash data.password)
    usr = get !!<db.getUser(u)

  login req, usr


proc saveAsset(req: Request): Id {.adminOnly.} =
  # FIXME add extension of file
  let multip = req.decodeMultipart()

  for entry in multip:
    if entry.data.isSome:
      let
        (start, last) = entry.data.get
        content = req.body[start..last]
        (_, name, ext) = splitFile entry.filename.get
        mime = mimetype ext
        oid = genOid()
        storePath = fmt"./resources/{oid}{ext}"

      writeFile storePath, content
      return !!<db.addAsset(name, mime, Path storePath, Bytes len start..last)

  raise newException(ValueError, "no files found")

proc assetsUpload*(req: Request) {.adminOnly.} =
  respJson str saveAsset req

proc assetShorthand*(req: Request) =
  let qi = req.uri.find('?')
  if qi == -1:
    notFoundHandler req
  else:
    let assetid = req.uri[qi+1..^1]
    redirect get_assets_download_url parseInt assetid

proc assetsDownload*(req: Request) {.qparams: {id: int}.} =
  let
    asset = !!<db.findAsset(id)
    content = readfile asset.path

  respFile asset.mime, content

proc deleteAsset*(req: Request) {.qparams: {id: int}, adminOnly.} =
  !!db.deleteAsset id
  resp OK


proc newNote*(req: Request) {.adminOnly.} =
  let id = !!<db.newNote()
  redirect get_note_editor_url id

proc getNote*(req: Request) {.qparams: {id: int}.} =
  !!respJson toJson db.getNote(id)

proc getNoteContentQuery*(req: Request) {.qparams: {id: int, path: seq[int]}.} =
  let node = !!<db.getNote(id).data
  respJson toJson node.follow path

proc updateNoteContent*(req: Request) {.qparams: {id: int}, jbody: TreeNodeRaw[
    JsonNode], adminOnly.} =
  !!db.updateNoteContent(id, data)
  resp OK

proc updateNoteRelTags*(req: Request) {.qparams: {id: int},
    jbody: RelValuesByTagId, adminOnly.} =
  !!db.updateNoteRelTags(id, data)
  resp OK

proc deleteNote*(req: Request) {.qparams: {id: int}, adminOnly.} =
  !!db.deleteNote id
  resp OK


proc newBoard*(req: Request) {.adminOnly.} =
  let id = !!<db.newBoard()
  redirect get_board_editor_url id

proc updateBoardContent*(req: Request) {.qparams: {id: int}, jbody: BoardData, adminOnly.} =
  !!db.updateBoardContent(id, data)
  resp OK

proc updateBoardScreenShot*(req: Request) {.qparams: {id: int}, adminOnly.} =
  !!db.setBoardScreenShot(id, saveAsset req)
  resp OK

proc updateBoardTitle*(req: Request) {.qparams: {id: int, title: string}, adminOnly.} =
  !!db.updateBoardTitle(id, title)
  resp OK

proc getBoard*(req: Request) {.qparams: {id: int}.} =
  !!respJson toJson db.getBoard(id)

proc deleteBoard*(req: Request) {.qparams: {id: int}, adminOnly.} =
  !!db.deleteBoard id
  resp OK


proc newTag*(req: Request) {.jbody: Tag, adminOnly.} =
  !!respJson toJson db.newTag data

proc updateTag*(req: Request) {.qparams: {id: int}, jbody: Tag, adminOnly.} =
  !!db.updateTag(id, data)
  resp OK

proc deleteTag*(req: Request) {.qparams: {id: int}, adminOnly.} =
  !!db.deleteTag id
  resp OK

proc listTags*(req: Request) =
  !!respJson toJson db.listTags


proc exploreNotes*(req: Request) {.jbody: ExploreQuery.} =
  !!respJson toJson db.exploreNotes(data)

proc exploreBoards*(req: Request) {.jbody: ExploreQuery.} =
  !!respJson toJson db.exploreBoards(data)

proc exploreAssets*(req: Request) {.jbody: ExploreQuery.} =
  !!respJson toJson db.exploreAssets(data)

proc exploreUsers*(req: Request) {.qparams: {name: string}.} =
  !!respJson toJson db.exploreUser(name)


proc getPalette*(req: Request) {.qparams: {name: string}.} =
  !!respJson toJson db.getPalette(name).colorThemes


proc proxyDownload*(req: Request) {.qparams: {url: string}.} =
  req.respond(200, body = download url)

proc fetchGithubCode*(req: Request) {.qparams: {url: string}.} =
  respJson toJson parseGithubJsFile download url

proc fetchLinkPreivewData*(req: Request) {.qparams: {url: string}.} =
  respJson toJson linkPreviewData parseHtml cropHead download url
