import std/[jsffi, asyncjs]

type
    FontFaceObserver* {.nodecl, importjs.} = object


func newFontFaceObserver*(ff: cstring): FontFaceObserver
    {.importjs: "new FontFaceObserver(@)".}

# TODO use time unit like MilliSecond or Second
proc load*(ffo: FontFaceObserver, timeout = 10_000): Future[void] 
    {.importjs: "#.load(null, #)".}
