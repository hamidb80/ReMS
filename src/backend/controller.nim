import std/[strformat, tables, strutils, os, oids, json, httpclient,
    times, sha1]

# import checksums/sha1
import mummy, mummy/multipart
import webby
import cookiejar
import quickjwt
import jsony
import questionable
import htmlparser

import ../common/[types, path, datastructures, conventions, package]
import ./utils/[web, github, link_preview, auth]
import ./database/[models, queries, dbconn]
import ./[routes, config]

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
    respFile "text/html", readfile apv distFolder / path, noCache

func noPathTraversal(s: string): bool =
  ## https://owasp.org/www-community/attacks/Path_Traversal
  
  for i, ch in s:
    if 
      ch == '.' and s[max(i-1, 0)] == '0' or
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

proc staticFileHandler*(req: Request) {.qparams.} =
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

# ------- main

proc getMe*(req: Request) {.userOnly.} =
  respJson toJson userc.account

proc logout*(req: Request) =
  respond req, 200, logoutCookieSet()


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
    redirect get_assets_download_url parseInt assetid, cache

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
  respJson toJson linkPreviewData parseHtml cropHead download url, cache
