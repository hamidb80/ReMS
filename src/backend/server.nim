import std/nativesockets

import mummy

import ./routes
import ../common/types


const hostUrl =
  when defined localhost: "localhost"
  else: "0.0.0.0"

proc runWebServer*(port: Port) {.noreturn.} =
  {.cast(gcsafe).}:
    var server = newServer(router, maxBodyLen = 5.Mb)
    serve server, port, hostUrl
