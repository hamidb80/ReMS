import std/[strformat, strtabs, tables, strutils, os, oids]

import mummy, mummy/multipart
import waterpark/sqlite

import ../common/path, ./utils/web, ./routes
import ../frontend/pages/html
import ./database/[models, queries]


# ------- Database stuff

let pool = newSqlitePool(10, "./play.db")

template withConn(db, body): untyped =
  pool.withConnnection db:
    body

block db_init:
  withConn db:
    createTables db

# ------- Static pages

proc staticFileHandler*(req: Request) {.addQueryParams.} =
  if "file" in q:
    let
      fname = q["file"]
      ext = getExt fname
      mime = getMimeType ext
      fpath = projectHome / "dist" / fname

    if fileExists fpath:
      req.respond(200, @{"Content-Type": mime}, readFile fpath)

    else: req.respond(404)
  else: req.respond(404)


proc notFoundHandler*(req: Request) =
  req.respond(404, @{"Content-Type": "text/html"}, "what? " & req.uri)

proc errorHandler*(req: Request, e: ref Exception) =
  echo e.msg
  req.respond(500, @[], e.msg)


proc toHtmlHandler*(page: string): RequestHandler =
  proc(req: Request) =
    req.respond(200, @{"Content-Type": "text/html"}, page)


let
  indexPage* = toHtmlHandler "Hey!"
  boardPage* = toHtmlHandler boardPageStr
  assetsPage* = toHtmlHandler assetsPageStr
  tagsPage* = toHtmlHandler tagsPageStr
  editorPage* = toHtmlHandler editorPageStr


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
      withConn db:
        let id = db.addAsset(storePath.Path)
        req.respond(200, @{"Content-Type": "application/json"}, $id)
        return

  req.respond(400, @{"Content-Type": "text/plain"}, "no")

proc assetShorthand*(req: Request) =
  let qi = req.uri.find('?')
  if qi == -1:
    notFoundHandler req
  else:
    let assetid = req.uri[qi+1..^1]
    req.respond(302, @{"Location": get_assets_download_url parseInt assetid})

proc assetsDownload*(req: Request) {.addQueryParams.} =
  let id = parseInt q["id"]

  withConn db:
    let
      asset = db.findAsset(id)
      p = asset.path
      mime = p.mimetype
      content = readfile p.string

    req.respond(200, @{"Content-Type": mime}, content)
    return

proc listAssets*(req: Request) =
  discard

