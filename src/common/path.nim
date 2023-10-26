import std/[mimetypes, strutils, macros, os]
import ./types


let m = newMimetypes()

func mimeType*(ext: string): string =
  {.cast(noSideEffect).}:
    getMimetype m, ext

func getExt*(s: string): string =
  s[s.rfind('.')+1 .. ^1]

func ext*(p: Path): string =
  getExt p.string


when not defined js:

  proc getProjectHome*: string =
    result = getProjectPath()

    while not dirExists result / "src":
      result = result / ".."

  const projectHome* = getProjectHome()

  template readfile*(p: Path): string = 
    readfile string p