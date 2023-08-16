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

  # get "/users/", assetsPage {.html.}
  # get "/api/user/search/"?(name: string), assetsPage {.html.}
  # get "/user/id/"?(id: int), assetsPage {.html.}
  # get "/me/", assetsPage {.html.}
  # get "/api/me/", assetsPage {.json.}
  # post "/api/me/update/", assetsPage {.json.}
  # get "/api/gen-invite-code/"?(user_id: int), assetsPage {.string.}

  get "/assets/", assetsPage {.html.}
  # get "/asset/"?(id: int), assetPreview {.html.}
  post "/assets/upload/", assetsUpload {.json.}
  get "/assets/download/"?(id: int), assetsDownload {.file.}
  get "/a", assetShorthand {.redirect.}
  get "/api/assets/list/", listAssets {.json.}
  # delete "/api/assets/", listAssets {.json.}
  
  get "/notes/", notesListPage {.html.}
  get "/note/editor/"?(id: int64), editorPage {.html.}
  get "/api/notes/list/", notesList {.json: seq[NotePreview].}
  post "/api/notes/new/", newNote {.json: note_id.}
  # put "/api/notes/update/", updateNote {.ok.}
  # get "/api/note/", getNote {.json: NoteFull.}
  # delete "/api/note/", deleteNote {.ok.}

  get "/boards/", boardPage {.html.}
  # get "/board/", boardPage {.html.}
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
