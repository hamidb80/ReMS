import std/[strformat]

import ../common/types
import ./utils/web
import ./auth


when not (defined(js) or defined(frontend)):
  # import ./auth
  import mummy/routers
  var router*: Router

dispatch router, ../controller:
  config "[not found]", notFoundHandler {.depends.}
  config "[method not allowed]", notFoundHandler {.depends.}
  config "[error]", errorHandler {.depends.}

  get "/", loadHtml"index.html" {.html.}
  get "/dist/"?(file: string), staticFileHandler {.file.}

  get "/profile/", loadHtml"profile.html" {.html.}
  post "/api/login/"?(kind: string), loginDispatcher {.ok.}
  get "/api/logout/", logout {.ok.}

  get "/api/profile/me/", getMe {.json: User.}
  # get "/api/profile/"?(id: int), getMe {.json: User.}
  # post "/api/profile/new/", getMe {.json: User.}
  # put "/api/profile/update/"?(id: int), getMe {.json: User.}

  post "/assets/upload/", assetsUpload {.form: File, Id.}
  get "/assets/download/"?(id: Id), assetsDownload {.file.}
  get "/a", assetShorthand {.redirect.}
  get "/asset/preview/"?(id: Id), loadHtml"asset-preview.html" {.html.}
  get "/api/asset/"?(id: Id), getAsset {.json.}
  get "/api/asset/update/name/"?(id: Id, name: string), updateAssetName {.ok.}
  put "/api/asset/update/tags/"?(id: Id), updateAssetRelTags {.ok.}
  delete "/api/asset/"?(id: Id), deleteAsset {.ok.}

  get "/notes/new/", newNote {.redirect.}
  get "/note/editor/"?(id: Id), loadHtml"editor.html" {.html.}
  get "/note/preview/"?(id: Id), loadHtml"note-preview.html" {.html.}
  get "/api/note/new/", newNoteApi {.json: Id.}
  get "/api/note/"?(id: Id), getNote {.json: Note.}
  get "/api/note/content/query/"?(id: Id, path: seq[int]),
      getNoteContentQuery {.json: Note.}
  put "/api/notes/update/content/"?(id: Id),
      updateNoteContent {.form: Note.data, ok.}
  put "/api/notes/update/tags/"?(id: Id), updateNoteRelTags {.form: Note.data, ok.}
  delete "/api/note/"?(id: Id), deleteNote {.ok.}

  # 'Pages' are just views for notes with predefined criteria
  # get "/page/"?(s: string), loadHtml"page.html" {.html.}
  # get "/api/page/"?(page: string, start: Id, limit: int), page {.json: seq[Note].}

  get "/boards/new/", newBoard {.Id.}
  get "/board/edit/"?(id: Id), loadHtml"board.html" {.html.}
  get "/api/board/"?(id: Id), getBoard {.json: Board.}
  put "/api/board/title/"?(id: Id, title: string), updateBoardTitle {.ok.}
  put "/api/board/content/"?(id: Id), updateBoardContent {.ok.}
  put "/api/board/screenshot/"?(id: Id), updateBoardScreenShot {.ok.}
  put "/api/board/update/tags/"?(id: Id), updateBoardRelTags {.ok.}
  delete "/api/board/"?(id: Id), deleteBoard {.ok.}

  get "/api/tags/list/", listTags {.json: seq[Tag].}
  post "/api/tag/new/", newTag {.Id.}
  put "/api/tag/update/"?(id: Id), updateTag {.ok.}
  delete "/api/tag/"?(id: Id), deleteTag {.ok.}

  get "/api/palette/"?(name: string), getPalette {.json: seq[ColorTheme].}
  get "/api/palettes/", listPalettes {.json: seq[Palette].}
  put "/api/update/palette/"?(name: string), updatePalette {.json: Palette.}
  # post "/api/palette/new/"?(name: string),
  # put "/api/palette/update/"?(name: string),
  # delete "/api/palette/"?(name: string)

  get "/explore/", loadHtml"explore.html" {.html.}
  post "/api/explore/notes/"?(offset: int, limit: int), exploreNotes {.json.}
  post "/api/explore/boards/"?(offset: int, limit: int), exploreBoards {.json.}
  post "/api/explore/assets/"?(offset: int, limit: int), exploreAssets {.json.}
  get "/api/explore/users/"?(name: string, offset: int, limit: int),
      exploreUsers {.json.}

  # to aviod CORS
  get "/api/utils/github/code/"?(url: string), fetchGithubCode {.json.}
  get "/api/utils/link/preview/"?(url: string), fetchLinkPreivewData {.json.}


func get_asset_short_hand_url*(asset_id: Id): string =
  "/a?" & $asset_id
