import std/[jsffi]

func mdParse*(s: cstring): cstring {.importjs: "marked.parse(@)".}