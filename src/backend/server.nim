import std/nativesockets

import mummy, mummy/routers

import ./routes, ./controller
import ../common/types
import ./utils/web

var router = Router()
# config "[not found]", notFoundHandler {.depends.}
# config "[method not allowed]", notFoundHandler {.depends.}
# config "[error]", errorHandler {.depends.}

router.get ur"home", landingPageHandler
router.get ur"dist", staticFileHandler

# router.get "/profile/", loadHtml"profile.html" {.html.}
# router.post "/api/login/"?(kind: string), loginDispatcher {.ok.}
# router.get "/api/logout/", logout {.ok.}

# router.get "/api/profile/me/", getMe {.json: User.}
# router.# get "/api/profile/"?(id: int), getMe {.json: User.}
# router.# post "/api/profile/new/", getMe {.json: User.}
# router.# put "/api/profile/update/"?(id: int), getMe {.json: User.}

# router.post "/assets/upload/", assetsUpload {.form: File, Id.}
# router.get "/assets/download/"?(id: Id), assetsDownload {.file.}
# router.get "/a", assetShorthand {.redirect.}
# router.get "/asset/preview/"?(id: Id), loadHtml"asset-preview.html" {.html.}
# router.get "/api/asset/"?(id: Id), getAsset {.json.}
# router.get "/api/asset/update/name/"?(id: Id, name: string), updateAssetName {.ok.}
# router.put "/api/asset/update/tags/"?(id: Id), updateAssetRelTags {.ok.}
# router.delete "/api/asset/"?(id: Id), deleteAsset {.ok.}

# router.get "/notes/new/", newNote {.redirect.}
# router.get "/note/editor/"?(id: Id), loadHtml"editor.html" {.html.}
# router.get "/note/preview/"?(id: Id), loadHtml"note-preview.html" {.html.}
# router.get "/api/note/new/", newNoteApi {.json: Id.}
# router.get "/api/note/"?(id: Id), getNote {.json: Note.}
# router.get "/api/note/content/query/"?(id: Id, path: seq[int]),
#     getNoteContentQuery {.json: Note.}
# router.put "/api/notes/update/content/"?(id: Id),
#     updateNoteContent {.form: Note.data, ok.}
# router.put "/api/notes/update/tags/"?(id: Id), updateNoteRelTags {.form: Note.data, ok.}
# router.delete "/api/note/"?(id: Id), deleteNote {.ok.}

# # 'Pages' are just views for notes with predefined criteria
# router.# get "/page/"?(s: string), loadHtml"page.html" {.html.}
# router.# get "/api/page/"?(page: string, start: Id, limit: int), page {.json: seq[Note].}

# router.get "/boards/new/", newBoard {.Id.}
# router.get "/board/edit/"?(id: Id), loadHtml"board.html" {.html.}
# router.get "/api/board/"?(id: Id), getBoard {.json: Board.}
# router.put "/api/board/title/"?(id: Id, title: string), updateBoardTitle {.ok.}
# router.put "/api/board/content/"?(id: Id), updateBoardContent {.ok.}
# router.put "/api/board/screenshot/"?(id: Id), updateBoardScreenShot {.ok.}
# router.put "/api/board/update/tags/"?(id: Id), updateBoardRelTags {.ok.}
# router.delete "/api/board/"?(id: Id), deleteBoard {.ok.}

# router.get "/api/tags/list/", listTags {.json: seq[Tag].}
# router.post "/api/tag/new/", newTag {.Id.}
# router.put "/api/tag/update/"?(id: Id), updateTag {.ok.}
# router.delete "/api/tag/"?(id: Id), deleteTag {.ok.}

# router.get "/api/palette/"?(name: string), getPalette {.json: seq[ColorTheme].}
# router.get "/api/palettes/", listPalettes {.json: seq[Palette].}
# router.put "/api/update/palette/"?(name: string), updatePalette {.json: Palette.}
# router.# post "/api/palette/new/"?(name: string),
# router.# put "/api/palette/update/"?(name: string),
# router.# delete "/api/palette/"?(name: string)

# router.get "/explore/", loadHtml"explore.html" {.html.}
# router.post "/api/explore/notes/"?(offset: int, limit: int), exploreNotes {.json.}
# router.post "/api/explore/boards/"?(offset: int, limit: int), exploreBoards {.json.}
# router.post "/api/explore/assets/"?(offset: int, limit: int), exploreAssets {.json.}
# router.get "/api/explore/users/"?(name: string, offset: int, limit: int),
#     exploreUsers {.json.}

# # to aviod CORS
# router.get "/api/utils/github/code/"?(url: string), fetchGithubCode {.json.}
# router.get "/api/utils/link/preview/"?(url: string), fetchLinkPreivewData {.json.}



proc runWebServer*(host: string, port: Port) {.noreturn.} =
  {.cast(gcsafe).}:
    var server = newServer(router, maxBodyLen = 5.Mb)
    serve server, port, host
