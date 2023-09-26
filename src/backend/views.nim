import std/[strformat, tables, strutils, os, oids, json, httpclient]

import mummy, mummy/multipart
import jsony
import waterpark/sqlite

import ../common/[types, path, datastructures, conventions]
import ./utils/web, ./routes
import ./database/[models, queries]

include ./database/jsony_fix


# ------- Database stuff

let pool = newSqlitePool(10, "./play.db")

template withConn(db, body): untyped =
  pool.withConnnection db:
    body

template `!!`*(dbworks): untyped {.dirty.} =
  withConn db:
    dbworks

template `!!<`*(dbworks): untyped {.dirty.} =
  block:
    proc test(db: DbConn): auto =
      dbworks

    var t: typeof test(default DbConn)
    withConn db:
      t = dbworks
    t

block db_init:
  !!createTables db

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

# proc exploreUsers*(req: Request) =


proc saveAsset(req: Request): Id =
  # FIXME model changed -
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
      return !!<db.addAsset(name, mime, storePath.Path, Bytes len start..last)

  raise newException(ValueError, "no files found")

proc assetsUpload*(req: Request) =
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

proc deleteAsset*(req: Request) {.qparams: {id: int}.} =
  !!db.deleteAsset id
  resp OK


proc newNote*(req: Request) =
  !!respJson str db.newNote()

proc getNote*(req: Request) {.qparams: {id: int}.} =
  !!respJson toJson db.getNote(id)

proc getNoteContentQuery*(req: Request) {.qparams: {id: int, path: seq[int]}.} =
  let node = !!<db.getNote(id).data
  respJson toJson node.follow path

proc updateNoteContent*(req: Request) {.qparams: {id: int}, jbody: TreeNodeRaw[JsonNode].} =
  !!db.updateNoteContent(id, data)
  resp OK

proc updateNoteRelTags*(req: Request) {.qparams: {id: int},
    jbody: RelValuesByTagId.} =
  !!db.updateNoteRelTags(id, data)
  resp OK

proc deleteNote*(req: Request) {.qparams: {id: int}.} =
  !!db.deleteNote id
  resp OK


proc newBoard*(req: Request) =
  !!respJson str db.newBoard()

proc updateBoard*(req: Request) {.qparams: {id: int}, jbody: BoardData.} =
  !!db.updateBoard(id, data)
  resp OK

proc updateBoardScreenShot*(req: Request) {.qparams: {id: int}.} =
  !!db.setScreenShot(id, saveAsset req)
  resp OK

proc getBoard*(req: Request) {.qparams: {id: int}.} =
  !!respJson toJson db.getBoard(id)

proc deleteBoard*(req: Request) {.qparams: {id: int}.} =
  !!db.deleteBoard id
  resp OK


proc newTag*(req: Request) {.jbody: Tag.} =
  !!respJson toJson db.newTag data

proc updateTag*(req: Request) {.qparams: {id: int}, jbody: Tag.} =
  !!db.updateTag(id, data)
  resp OK

proc deleteTag*(req: Request) {.qparams: {id: int}.} =
  !!db.deleteTag id
  resp OK

proc listTags*(req: Request) =
  !!respJson toJson db.listTags


proc download(url: string): string =
  var client = newHttpClient()
  client.get(url).body

func htmlUnescape(str: string): string =
  str.multiReplace ("\\\"", "\""), ("\\n", "\n"), ("\\/", "/")

func parseGhFile(content: string): GithubCodeEmbed =
  ## as of 2023/10/22 the Github embed `script.js` is in pattern of:
  ##
  ## LINE_NUMBER| TEXT
  ## 1| document.write('<link rel="stylesheet" href="<CSS_FILE_URL">')
  ## 2| document.write('escaped string of HTML content')
  ## 3|

  const
    linkStamps = "href=\"" .. "\">')"
    codeStamps = "document.write('" .. "')"

  let
    parts = splitlines content
    cssLinkStart = parts[0].find linkStamps.a
    cssLinkEnd = parts[0].rfind linkStamps.b
    htmlCodeEnd = parts[1].rfind codeStamps.b

  result.styleLink = parts[0][(cssLinkStart + linkStamps.a.len) ..< cssLinkEnd]
  result.htmlCode = htmlUnescape parts[1][codeStamps.a.len ..< htmlCodeEnd]

proc fetchGithubCode*(req: Request) {.qparams: {url: string}.} =
  respJson toJson parseGhFile download url

proc getPalette*(req: Request) {.qparams: {name: string}.} =
  !!respJson toJson db.getPalette(name).colorThemes


proc exploreUsers*(req: Request) =
  resp OK

proc exploreNotes*(req: Request) {.jbody: ExploreQuery.} =
  !!respJson toJson db.exploreNotes(data)

proc exploreBoards*(req: Request) {.jbody: ExploreQuery.} =
  !!respJson toJson db.exploreBoards(data)

proc exploreAssets*(req: Request) {.jbody: ExploreQuery.} =
  !!respJson toJson db.exploreAssets(data)
