import std/[strformat, macros]
import mummy/routers
import ./views, ./utils/router as r


var router*: Router
router.notFoundHandler = notFoundHandler
router.methodNotAllowedHandler = notFoundHandler
router.errorHandler = errorHandler

dispatch router:
  get "/dist/"?(file: string), staticFileHandler {.file.}
  
  get "/", indexPage {.html.}
  get "/assets/", assetsPage {.html.}
  get "/boards/", boardPage {.html.}
  get "/notes/", editorPage {.html.}
  get "/tags/", tagsPage {.html.}

  # get "/api/tag/"?(id: int), tagsPage {.api.}
  # delete "/api/tag/"?(id: int), deleteTag {.api.}
