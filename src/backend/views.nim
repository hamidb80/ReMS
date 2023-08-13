import std/[
  strformat,  strtabs, tables, strutils,
  os, mimetypes]
import ../common/path, ./utils/web

when not defined js:
  import mummy, mummy/multipart
  import ../frontend/pages/html
  import std/oids

  const mft = toTable mimes

  func fileExtension(s: string): string =
    s[s.rfind('.')+1 .. ^1]

  proc staticFileHandler*(req: Request) {.addQueryParams.} =
    if "file" in q:
      let
        fname = q["file"]
        ext = fileExtension fname
        mime = mft[ext]
        fpath = projectHome / "dist" / fname

      if fileExists fpath:
        req.respond(200, @{"Content-Type": mime}, readFile fpath)

      else: req.respond(404)
    else: req.respond(404)

    echo q


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


  proc assetsUpload*(req: Request) =
    let multipartEntries = req.decodeMultipart()
    
    for entry in multipartEntries:
      if entry.data.isSome:
        let 
          (start, last) = entry.data.get
          oid = genOid()
          fname = entry.filename.get
          storePath = fmt"./resources/{oid}-{fname}"
        
        writeFile storePath, req.body[start..last]
        req.respond(200, @{"Content-Type": "application/json"}, "true")
        return

    req.respond(400, @{"Content-Type": "text/plain"}, "no")
