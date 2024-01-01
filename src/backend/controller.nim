import std/[strformat, tables, strutils, os, oids, json, httpclient,
    times, sha1]

# import checksums/sha1
import mummy, mummy/multipart
import webby
import quickjwt
import cookiejar
import jsony
import questionable
import bale
import htmlparser

import ../common/[types, path, datastructures, conventions, package]
import ./utils/[web, github, link_preview]
import ./routes
import ./database/[models, queries, dbconn]
import ./config

include ./database/jsony_fix


# ------- Static pages

proc notFoundHandler*(req: Request) =
  respErr 404, "what? " & req.uri

proc errorHandler*(req: Request, e: ref Exception) =
  echo e.msg, "\n\n", e.getStackTrace
  respErr 500, e.msg


const distFolder* = projectHome / "dist"

proc loadHtml*(path: string): RequestHandler =
  proc(req: Request) =
    respFile "text/html", readfile apv distFolder / path, false

func isFilename(s: string): bool =
  ## https://owasp.org/www-community/attacks/Path_Traversal
  for c in s:
    if c in invalidFilenameChars:
      return false
  true

proc loadDist*(filename: string): RequestHandler =
  doAssert isFilename filename, "illegal file name"

  let
    p = projectHome / "dist" / apv filename
    mime = mimeType getExt filename

  proc(req: Request) =
    respFile mime, readfile p, true

proc staticFileHandler*(req: Request) {.qparams.} =
  let
    fname = q.getOrDefault "file"
    ext = getExt fname
    mime = mimeType ext
    fpath = distFolder / fname

  if (fileExists fpath) and (isFilename fname):
    respFile mime, readFile fpath, true
  else: 
    resp 404

# ------- utility

proc download*(url: string): string =
  var client = newHttpClient()
  result = client.get(url).body
  close client


## https://community.auth0.com/t/rs256-vs-hs256-jwt-signing-algorithms/58609
const jwtKey = "auth"

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

proc jwtCookieSet(token: string): webby.HttpHeaders =
  result["Set-Cookie"] = $initCookie(jwtKey, token, now() + expireDays.days, path = "/")

proc jwt(req: Request): options.Option[string] =
  try:
    if "Cookie" in req.headers:
      let ck = initCookie req.headers["Cookie"]
      if ck.name == jwtKey:
        return some ck.value
  except:
    discard

proc login*(req: Request, uc: UserCache) =
  if uc.account.id != 1 or defined login_default_admin:
    {.cast(gcsafe).}:
      respond req, 200, jwtCookieSet toJwt uc

# ------- main

proc getMe*(req: Request) {.userOnly.} =
  respJson toJson userc.account

proc logoutCookieSet: webby.HttpHeaders =
  result["Set-Cookie"] = $initCookie(jwtKey, "", path = "/")

proc logout*(req: Request) =
  respond req, 200, logoutCookieSet()

func len[E: enum](e: type E): Natural =
  len e.low .. e.high

proc toEnumArr[E: enum, V](s: seq[V]): array[E, V] =
  assert len(E) == len(s)
  for i, x in s:
    result[E(i)] = x

proc loginWithInvitationCode*(req: Request) {.qparams: {secret: string}.} =
  let inv = !!<db.getInvitation(secret, unow(), 60)

  if i =? inv:
    let
      baleUser = bale.User i.data
      maybeAuth = !!<db.getAuthBale(baleUser.id)
      uid =
        if a =? maybeAuth: a.user
        else:
          let u = !!<db.newUser(
            "bale_" & $baleUser.id,
            baleUser.firstName & baleUser.lastname.get "",
            baleUser.id in adminBaleIds)
          discard !!<db.newAuth(u, baleUser.id)
          u

      maybeUsr = !!<db.getUser(uid)
      tags = !!<db.getLabeledTagIds()
      uc = UserCache(
        account: get maybeUsr,
        defaultTags: toEnumArr[TagLabel, Id](tags))

    login req, uc
    !!db.loginNotif(uid)

  else:
    resp 404

proc loginWithForm*(req: Request) {.jbody: LoginForm.} =
  ## sign up with form is not possible, only from bale and enabeling password later
  let
    u = get !!<db.getUser(data.username)
    a = get !!<db.getAuthUser(u.id)

  if hash =? a.hashedPass:
    if hash == secureHash data.password:
      login req, UserCache(
        account: u,
        defaultTags: toEnumArr[TagLabel, Id](!!<db.getLabeledTagIds()))
    else:
      # TODO add syntax sugar for errors
      raise newException(ValueError, "password is not valid")
  else:
    raise newException(ValueError, "the user does not set login with password")

proc getAsset*(req: Request) {.qparams: {id: int}.} =
  !!respJson toJson db.getAsset(id)

proc updateAssetName*(req: Request) {.qparams: {id: int, name: string}, userOnly.} =
  !! db.updateAssetName(userc.account, id, name)
  resp OK

proc updateAssetRelTags*(req: Request) {.qparams: {id: int},
    jbody: RelValuesByTagId, userOnly.} =
  !! db.updateAssetRelTags(userc.account, id, data)
  resp OK

proc saveAsset(req: Request): Id {.userOnly.} =
  let multip = req.decodeMultipart()

  for entry in multip:
    if entry.data.isSome:
      let
        (start, last) = entry.data.get
        content = req.body[start..last]
        (_, name, ext) = splitFile entry.filename.get
        fname = name & ext
        mime = mimetype ext
        oid = genOid()
        timestamp = toUnix getTime()

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
    redirect get_assets_download_url parseInt assetid, true

proc assetsDownload*(req: Request) {.qparams: {id: int}.} =
  # TODO return a default image if not exists
  let
    asset = !!<db.findAsset(id)
    content = readfile asset.path

  respFile asset.mime, content, true

proc deleteAsset*(req: Request) {.qparams: {id: int}, userOnly.} =
  !!db.deleteAssetLogical(userc.account, id, unow())
  resp OK


proc newNote*(req: Request) {.userOnly.} =
  let id = forceSafety !!<db.newNote(userc.account)
  redirect get_note_editor_url id

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
    jbody: RelValuesByTagId, userOnly.} =
  !!db.updateNoteRelTags(userc.account, id, data)
  resp OK

proc deleteNote*(req: Request) {.qparams: {id: int}, userOnly.} =
  !!db.deleteNoteLogical(userc.account, id, unow())
  resp OK


proc newBoard*(req: Request) {.userOnly.} =
  let id = !!<db.newBoard(userc.account)
  redirect get_board_edit_url id

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
    jbody: RelValuesByTagId, userOnly.} =
  !!db.updateBoardRelTags(userc.account, id, data)
  resp OK

proc getBoard*(req: Request) {.qparams: {id: int}.} =
  !!respJson toJson db.getBoard(id)

proc deleteBoard*(req: Request) {.qparams: {id: int}, userOnly.} =
  !!db.deleteBoardLogical(userc.account, id, unow())
  resp OK


proc newTag*(req: Request) {.jbody: Tag, userOnly.} =
  !!respJson toJson db.newTag(userc.account, data)

proc updateTag*(req: Request) {.qparams: {id: int}, jbody: Tag, userOnly.} =
  !!db.updateTag(userc.account, id, data)
  resp OK

proc deleteTag*(req: Request) {.qparams: {id: int}, userOnly.} =
  !!db.deleteTag(userc.account, id)
  resp OK

proc listTags*(req: Request) =
  !!respJson toJson db.listTags


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
