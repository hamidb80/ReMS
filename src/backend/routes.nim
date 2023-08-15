import std/[strformat]
import ./utils/web

when not (defined(js) or defined(frontend)):
  import mummy/routers
  var router*: Router

dispatch router, ../views:
  config "[not found]", notFoundHandler {.depends.}
  config "[method not allowed]", notFoundHandler {.depends.}
  config "[error]", errorHandler {.depends.}

  get "/", indexPage {.html.}
  get "/dist/"?(file: string), staticFileHandler {.file.}

  get "/assets/", assetsPage {.html.}
  # get "/asset/"?(id: int), assetPreview {.html.}
  post "/assets/upload/", assetsUpload {.json.}
  get "/assets/download/"?(id: int), assetsDownload {.file.}
  get "/a", assetShorthand {.redirect.}
  get "/api/assets/list/", listAssets {.json.}
  # delete "/api/assets/", listAssets {.json.}
  
  get "/notes/", editorPage {.html.}
  get "/note/"?(id: int), editorPage {.html.}
  # post "/api/notes/new/", listAssets {.json.}
  # put "/api/notes/update/", listAssets {.json.}
  # get "/api/notes/list/", listAssets {.json.}
  # get "/api/note/", listAssets {.json.}
  # delete "/api/note/", listAssets {.json.}

  get "/boards/", boardPage {.html.}
  get "/board/", boardPage {.html.}
  # post "/api/board/new/", listAssets {.json.}
  # put "/api/board/update/", listAssets {.json.}
  # get "/api/boards/list/", listAssets {.json.}
  # get "/api/board/", listAssets {.json.}
  # delete "/api/board/", listAssets {.json.}

  get "/tags/", tagsPage {.html.}
  # post "/api/tag/new/", listAssets {.json.}
  # put "/api/tag/update/", listAssets {.json.}
  # get "/api/tags/list/", listAssets {.json.}
  # get "/api/tag/", listAssets {.json.}
  # delete "/api/tag/", listAssets {.json.}
  

func get_asset_short_hand_url*(asset_id: int64): string =
  "/a?" & $asset_id
