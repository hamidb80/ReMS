import std/nativesockets

import mummy

import ./routes
import ../common/types


proc runWebServer*(port: Port) {.noreturn.} =
  {.cast(gcsafe).}:
    var server = newServer(router, maxBodyLen = 5.Mb)
    serve server, port
