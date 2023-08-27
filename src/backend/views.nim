import std/[strformat, strtabs, strutils, os, oids, json]

import mummy, mummy/multipart
import jsony
import waterpark/sqlite

import ../common/[types, path, datastructures, conventions]
import ./utils/web, ./routes
import ./database/[models, queries]

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
  echo e.msg
  respErr 500, e.msg

proc staticFileHandler*(req: Request) {.addQueryParams.} =
  if "file" in q:
    let
      fname = q["fil2e"]
      ext = getExt fname
      mime = getMimeType ext
      fpath = projectHome / "dist" / fname

    if fileExists fpath:
      req.respond(200, @{"Content-Type": mime}, readFile fpath)

    else: resp 404
  else: resp 404

proc loadDist*(path: string): RequestHandler =
  let
    p = projectHome / "dist" / path
    mime = getMimeType getExt p

  proc(req: Request) =
    req.respond(200, @{"Content-Type": mime}, readfile p)


# ------- Dynamic ones

proc assetsUpload*(req: Request) =
  let multipartEntries = req.decodeMultipart()

  for entry in multipartEntries:
    if entry.data.isSome:
      let
        (start, last) = entry.data.get
        oid = genOid()
        fname = entry.filename.get
        ext = getExt fname
        storePath = fmt"./resources/{oid}.{ext}"

      writeFile storePath, req.body[start..last]
      let id = !!<db.addAsset(fname, storePath.Path, Bytes last-start+1)
      respJson str id
      return

  respErr "no"

proc assetShorthand*(req: Request) =
  let qi = req.uri.find('?')
  if qi == -1:
    notFoundHandler req
  else:
    let assetid = req.uri[qi+1..^1]
    redirect get_assets_download_url parseInt assetid

proc assetsDownload*(req: Request) {.addQueryParams: {id: int}.} =
  let
    asset = !!<db.findAsset(id)
    p = asset.path
    mime = p.mimetype
    content = readfile p.string

  req.respond(200, @{"Content-Type": mime}, content)

proc listAssets*(req: Request) =
  !!respJson toJson db.listAssets()

proc deleteAsset*(req: Request) {.addQueryParams: {id: int}.} =
  !!db.deleteAsset id
  resp OK


proc newNote*(req: Request) =
  !!respJson str db.newNote()

proc notesList*(req: Request) =
  !!respJson toJson db.listNotes()

proc getNote*(req: Request) {.addQueryParams: {id: int}.} =
  !!respJson toJson db.getNote(id)

proc updateNote*(req: Request) {.addQueryParams: {id: int}.} =
  let d = fromJson(req.body, TreeNodeRaw[JsonNode])
  !!db.updateNote(id, d)
  resp OK

proc deleteNote*(req: Request) {.addQueryParams: {id: int}.} =
  !!db.deleteNote id
  resp OK


proc newBoard*(req: Request) =
  !!respJson str db.newBoard()

proc updateBoard*(req: Request) {.addQueryParams: {id: int}.} =
  let data = fromJson(req.body, BoardData)
  !!db.updateBoard(id, data)
  resp OK

proc updateBoardScreenShot*(req: Request) {.addQueryParams: {id: int}.} =
  discard

proc getBoard*(req: Request) {.addQueryParams: {id: int}.} =
  !!respJson toJson db.getBoard(id)

proc listBoards*(req: Request) =
  !!respJson toJson db.listBoards()

proc deleteBoard*(req: Request) {.addQueryParams: {id: int}.} =
  !!db.deleteBoard id
  resp OK
