import std/[mimetypes, strutils, macros, os]
import ./types


func getMimeType*(ext: string): string =
  {.cast(noSideEffect).}:
    let m {.global.} = newMimetypes()
    m.getMimetype ext

func getExt*(s: string): string =
  s[s.rfind('.')+1 .. ^1]

func ext*(p: Path): string =
  getExt p.string

func mimetype*(p: Path): string =
  p.ext.getMimeType


when not defined js:
  proc getProjectHome*: string =
    result = getProjectPath()

    while not dirExists result / "src":
      result = result / ".."

  const projectHome* = getProjectHome()
