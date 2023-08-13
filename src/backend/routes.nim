import std/[strformat, macros]
import mummy/routers
import ./views, ./utils/router as r


var router*: Router

dispatch router:
  config "[not found]", notFoundHandler {.depends.}
  config "[method not allowed]", notFoundHandler {.depends.}
  config "[error]", errorHandler {.depends.}

  get "/dist/"?(file: string), staticFileHandler {.file.}

  get "/", indexPage {.html.}
  get "/assets/", assetsPage {.html.}
  get "/boards/", boardPage {.html.}
  get "/notes/", editorPage {.html.}
  get "/tags/", tagsPage {.html.}

  # get "/api/tag/"?(id: int), tagsPage {.api.}
  # delete "/api/tag/"?(id: int), deleteTag {.api.}
