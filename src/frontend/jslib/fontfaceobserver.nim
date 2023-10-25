import std/[jsffi, asyncjs]

type
    FontFaceObserver* {.nodecl, importjs.} = object


func newFontFaceObserver*(ff: cstring): FontFaceObserver
    {.importjs: "new FontFaceObserver(@)".}

proc load*(ffo: FontFaceObserver, testString: cstring,
        timeout = 10_000): Future[void]
    {.importjs: "#.load(#, #)".}
