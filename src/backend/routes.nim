import std/[strformat]
import ./utils/web

when not defined js:
  import mummy/routers
  var router*: Router

dispatch router, ../views:
  config "[not found]", notFoundHandler {.depends.}
  config "[method not allowed]", notFoundHandler {.depends.}
  config "[error]", errorHandler {.depends.}

  get "/dist/"?(file: string), staticFileHandler {.file.}

  get "/", indexPage {.html.}
  get "/assets/", assetsPage {.html.}
  get "/boards/", boardPage {.html.}
  get "/notes/", editorPage {.html.}
  get "/tags/", tagsPage {.html.}

  post "/assets/upload/", assetsUpload {.json: {id: int}.}
  get "/assets/download/"?(id: int), assetsDownload {.file.}
  get "/@", assetShorthand {.redirect.}
  get "/api/assets/list/", listAssets {.json.}


func get_asset_short_hand_url*(asset_id: int): string =
  "/@?" & $asset_id
