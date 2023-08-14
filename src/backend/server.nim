import mummy
import routes
import ../common/types


when isMainModule:
  var server = newServer(router, maxBodyLen = 5.Mb)
  echo "Serving on http://localhost:8080"
  server.serve 8080.Port
