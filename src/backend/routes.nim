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

  get "/login/", loadDist"login.html" {.html.}
  post "/api/login/", login {.OK.}
  get "/api/logout/", logout {.OK.}
  # TODO
  # get "/me/", usersPage {.html.}
  # put "/api/me/" usersPage {.json.}
  # get "/user/id/"?(id: int), usersPage {.html.}
  # get "/api/gen-invite-code/"?(user_id: int), usersPage {.string.}

  get "/assets/", loadDist"assets.html" {.html.}
  # get "/asset/preview/"?(id: int), assetPreview {.html.}
  post "/assets/upload/", assetsUpload {.form: File, Id.}
  get "/assets/download/"?(id: Id), assetsDownload {.file.}
  get "/a", assetShorthand {.redirect.}
  delete "/api/asset/"?(id: Id), deleteAsset {.json.}

  get "/notes/new/", newNote {.Id.}
  get "/note/editor/"?(id: Id), loadDist"editor.html" {.html.}
  get "/api/note/"?(id: Id), getNote {.json: Note.}
  get "/api/note/content/query/"?(id: Id, path: seq[int]),
      getNoteContentQuery {.json: Note.}
  put "/api/notes/update/content/"?(id: Id), updateNoteContent {.form: Note.data, ok.}
  put "/api/notes/update/tags/"?(id: Id), updateNoteRelTags {.form: Note.data, ok.}
  delete "/api/note/"?(id: Id), deleteNote {.ok.}

  # 'Pages' are just views for notes with predefined criteria
  # get "/page/"?(s: string), loadDist"page.html" {.html.}
  # get "/api/page/"?(page: string, start: Id, limit: int), page {.json: seq[Note].}

  get "/boards/new/", newBoard {.Id.}
  get "/board/editor/"?(id: Id), loadDist"board.html" {.html.}
  get "/api/board/"?(id: Id), getBoard {.json: Board.}
  put "/api/board/update/"?(id: Id), updateBoard {.ok.}
  put "/api/board/screen-shot/"?(id: Id), updateBoardScreenShot {.ok.}
  delete "/api/board/"?(id: Id), deleteBoard {.ok.}

  get "/tags/", loadDist"tags.html" {.html.}
  get "/api/tags/list/", listTags {.json: seq[Tag].}
  post "/api/tag/new/", newTag {.Id.}
  put "/api/tag/update/"?(id: Id), updateTag {.ok.}
  delete "/api/tag/"?(id: Id), deleteTag {.ok.}

  get "/palette/"?(name: string), getPalette {.json: seq[ColorTheme].}
  get "/utils/github/code/"?(url: string), fetchGithubCode {.json.} ## to aviod CORS

  get "/explore/", loadDist"explore.html" {.html.}
  post "/api/explore/notes/", exploreNotes {.json.}
  post "/api/explore/boards/", exploreBoards {.json.}
  post "/api/explore/assets/", exploreAssets {.json.}
  get "/api/explore/users/", exploreUsers {.json.}



func get_asset_short_hand_url*(asset_id: Id): string =
  "/a?" & $asset_id
