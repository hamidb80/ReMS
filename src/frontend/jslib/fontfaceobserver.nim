import std/[jsffi, asyncjs]

type
    FontFaceObserver* = object {.nodecl, importjs.}


func newFontFaceObserver*(ff: cstring): FontFaceObserver
    {.importjs: "new FontFaceObserver(@)".}

# TODO use time unit like MilliSecond or Second
proc load*(ffo: FontFaceObserver, timeout = 10_000): Future[void] 
    {.importjs: "#.load(null, #)".}
