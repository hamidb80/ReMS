import mummy
import routes


when isMainModule:
  var server = newServer router
  echo "Serving on http://localhost:8080"
  server.serve 8080.Port