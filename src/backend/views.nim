import std/[strformat, strtabs, strutils, os, oids, json]

import mummy, mummy/multipart
import jsony
import waterpark/sqlite

import ../common/[types, path, datastructures]
import ./utils/web, ./routes
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

proc notFoundHandler*(req: Request) =
  req.respond(404, @{"Content-Type": "text/html"}, "what? " & req.uri)

proc errorHandler*(req: Request, e: ref Exception) =
  echo e.msg
  req.respond(500, @[], e.msg)

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
      withConn db:
        let id = db.addAsset(fname, storePath.Path, Bytes last-start+1)
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
  withConn db:
    req.respond(200, @{"Content-Type": "application/json"},
        toJson db.listAssets())

proc deleteAsset*(req: Request) {.addQueryParams.} =
  let id = q["id"].parseint
  withConn db:
    db.deleteAsset id
  req.respond 200


proc newNote*(req: Request) =
  withConn db:
    req.respond(200, @{"Content-Type": "application/json"}, $db.newNote())

proc notesList*(req: Request) =
  withConn db:
    req.respond(200, @{"Content-Type": "application/json"}, toJson db.listNotes())

## TODO addQueryParams: {id: int, ?name:string, ...}
proc getNote*(req: Request) {.addQueryParams.} =
  let id = q["id"].parseint
  withConn db:
    req.respond(200, @{"Content-Type": "application/json"}, toJson db.getNote(id))

proc updateNote*(req: Request) {.addQueryParams.} =
  let
    id = q["id"].parseint
    d = fromJson(req.body, TreeNodeRaw[JsonNode])

  withConn db:
    db.updateNote id, d
  req.respond 200

proc deleteNote*(req: Request) {.addQueryParams.} =
  let id = q["id"].parseint
  withConn db:
    db.deleteNote id
  req.respond 200



proc newBoard*(req: Request) =
  withConn db:
    req.respond(200, @{"Content-Type": "application/json"}, $db.newBoard())

proc updateBoard*(req: Request)  {.addQueryParams.} =
  let 
    id = q["id"].parseint
    d = fromJson(req.body, BoardData)

  withConn db:
    db.updateBoard id, d

  req.respond(200)

proc getBoard*(req: Request)  {.addQueryParams.} =
  let
    id = q["id"].parseint

  withConn db:
    req.respond(200, @{"Content-Type": "application/json"}, toJson db.getBoard(id))

proc listBoards*(req: Request)  {.addQueryParams.} =
  withConn db:
    req.respond(200, @{"Content-Type": "application/json"}, toJson db.listBoards)

proc deleteBoard*(req: Request) {.addQueryParams.} =
  let id = q["id"].parseint
  withConn db:
    db.deleteBoard id
  req.respond 200
