import std/[mimetypes, tables, os, strutils]
import mummy
import ../common/path, ./utils/view


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

when defined backend:
  import ../frontend/pages/html

  let
    indexPage* = toHtmlHandler "Hey!"
    boardPage* = toHtmlHandler boardPageStr
    assetsPage* = toHtmlHandler assetsPageStr
    tagsPage* = toHtmlHandler tagsPageStr
    editorPage* = toHtmlHandler editorPageStr
