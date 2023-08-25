import std/[strformat]
import ./utils/web
import ../common/types

when not (defined(js) or defined(frontend)):
  import mummy/routers
  var router*: Router

dispatch router, ../views:
  config "[not found]", notFoundHandler {.depends.}
  config "[method not allowed]", notFoundHandler {.depends.}
  config "[error]", errorHandler {.depends.}

  get "/", loadDist"index.html" {.html.}
  get "/dist/"?(file: string), staticFileHandler {.file.}

  # get "/users/", assetsPage {.html.}
  # get "/api/user/search/"?(name: string), assetsPage {.html.}
  # get "/user/id/"?(id: int), assetsPage {.html.}
  # get "/me/", assetsPage {.html.}
  # get "/api/me/", assetsPage {.json.}
  # post "/api/me/update/", assetsPage {.json.}
  # get "/api/gen-invite-code/"?(user_id: int), assetsPage {.string.}

  get "/assets/", loadDist"assets.html" {.html.}
  # get "/asset/"?(id: int), assetPreview {.html.}
  post "/assets/upload/", assetsUpload {.form: File, Id.}
  get "/assets/download/"?(id: Id), assetsDownload {.file.}
  get "/a", assetShorthand {.redirect.}
  get "/api/assets/list/", listAssets {.json.}
  delete "/api/asset/"?(id: Id), deleteAsset {.json.}
  
  get "/notes/", loadDist"notes_list.html" {.html.}
  get "/note/editor/"?(id: Id), loadDist"editor.html" {.html.}
  get "/api/notes/list/", notesList {.json: seq[Note].}
  get "/api/note/"?(id: Id), getNote {.json: Note.}
  post "/api/notes/new/", newNote {.Id.}
  put "/api/notes/update/"?(id: Id), updateNote {.form: Note.data, ok.}
  delete "/api/note/"?(id: Id), deleteNote {.ok.}

  get "/boards/", loadDist"boards.html" {.html.} ## TODO send screenshot of board with key `p` forexample and show it in list
  get "/api/boards/list", listBoards {.json: seq[BoardPreview].}
  get "/board/"?(id: Id), loadDist"board.html" {.html.}
  get "/api/board/"?(id: Id), getBoard {.json: Board.}
  post "/api/boards/new/", newBoard {.Id.}
  put "/api/board/update/"?(id: Id), updateBoard {.ok.}
  # send scrennshot
  delete "/api/board/"?(id: Id), deleteBoard {.ok.}

  get "/tags/", loadDist"tags.html" {.html.}
  # post "/api/tag/new/", newTag {.Id.}
  # put "/api/tag/update/"?(id: Id), updateTag {.ok.}
  # get "/api/tags/list/", listTags {.json: seq[].}
  # delete "/api/tag/"?(id: Id), deleteTag {.ok.}
  

func get_asset_short_hand_url*(asset_id: Id): string =
  "/a?" & $asset_id
