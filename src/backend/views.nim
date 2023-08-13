import mummy

proc indexHandler*(request: Request) =
  var headers: HttpHeaders
  headers["Content-Type"] = "text/plain"
  request.respond(200, headers, "Hello, World!")

