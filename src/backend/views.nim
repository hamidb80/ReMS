import std/[mimetypes, tables, os, strutils]
import mummy
import ../frontend/pages/html
import ../common/path

const mft = toTable mimes

func fileExtension(s: string): string =
  s[s.rfind('.')+1 .. ^1]

proc staticFileHandler*(req: Request) =
  let qi = req.uri.find '='
  if qi != -1:
    let
      fname = req.uri[qi+1 .. ^1]
      ext = fileExtension fname
      mime = mft[ext]
      fpath = projectHome / "dist" / fname

    echo fpath, ' ', fileExists fpath
    if fileExists fpath:
      req.respond(200, @{"Content-Type": mime}, readFile fpath)
      
    else: req.respond(404)
  else: req.respond(404)

proc indexHandler*(req: Request) =
  req.respond(200, @{"Content-Type": "text/html"}, indexPageStr)

proc notFoundHandler*(req: Request) =
  req.respond(404, @{"Content-Type": "text/html"}, "what? " & req.uri)
