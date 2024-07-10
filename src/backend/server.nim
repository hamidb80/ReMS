import std/[nativesockets, httpcore, with]

import mummy, mummy/routers

import ../common/types
import ./utils/web
import ./[urls, controller]
import ./views/partials


const
  GET  = HttpGet
  POST = HttpPost 

proc route(r: var Router, url: string, handler:  RequestHandler, methods: set[HttpMethod]) = 
  for m in methods:
    r.addRoute $m, url, handler

func initRouter: Router = 
  
  with result:
    methodNotAllowedHandler =  methodNotAllowedHandle
    notFoundHandler         =  notFoundHandler
    errorHandler            =  errorHandler

    route  ur"dist",     staticFileHandler   , {GET}
    route  ur"home",     landingPageHandler  , {GET}

    route  ur"sign-in",   signInHandler      , {GET, POST}
    route  ur"sign-up",   signUpFormHandler  , {GET, POST}
    route  ur"sign-out",  signOutHandler     , {GET}
    
    route  ur"my-profile",  myProfileHandler , {GET}
    
  # result.get "/api/profile/me/", getMe {.json: User.}

  # result.# get "/api/profile/"?(id: int), getMe {.json: User.}
  # result.# post "/api/profile/new/", getMe {.json: User.}
  # result.# put "/api/profile/update/"?(id: int), getMe {.json: User.}

  # result.post "/assets/upload/", assetsUpload {.form: File, Id.}
  # result.get "/assets/download/"?(id: Id), assetsDownload {.file.}
  # result.get "/a", assetShorthand {.redirect.}
  # result.get "/asset/preview/"?(id: Id), loadHtml"asset-preview.html" {.html.}
  # result.get "/api/asset/"?(id: Id), getAsset {.json.}
  # result.get "/api/asset/update/name/"?(id: Id, name: string), updateAssetName {.ok.}
  # result.put "/api/asset/update/tags/"?(id: Id), updateAssetRelTags {.ok.}
  # result.delete "/api/asset/"?(id: Id), deleteAsset {.ok.}

  # result.get "/notes/new/", newNote {.redirect.}
  # result.get "/note/editor/"?(id: Id), loadHtml"editor.html" {.html.}
  # result.get "/note/preview/"?(id: Id), loadHtml"note-preview.html" {.html.}
  # result.get "/api/note/new/", newNoteApi {.json: Id.}
  # result.get "/api/note/"?(id: Id), getNote {.json: Note.}
  # result.get "/api/note/content/query/"?(id: Id, path: seq[int]),
  # result.put "/api/notes/update/content/"?(id: Id),
  # result.put "/api/notes/update/tags/"?(id: Id), updateNoteRelTags {.form: Note.data, ok.}
  # result.delete "/api/note/"?(id: Id), deleteNote {.ok.}

  # # 'Pages' are just views for notes with predefined criteria
  # result.# get "/page/"?(s: string), loadHtml"page.html" {.html.}
  # result.# get "/api/page/"?(page: string, start: Id, limit: int), page {.json: seq[Note].}

  # result.get "/boards/new/", newBoard {.Id.}
  # result.get "/board/edit/"?(id: Id), loadHtml"board.html" {.html.}
  # result.get "/api/board/"?(id: Id), getBoard {.json: Board.}
  # result.put "/api/board/title/"?(id: Id, title: string), updateBoardTitle {.ok.}
  # result.put "/api/board/content/"?(id: Id), updateBoardContent {.ok.}
  # result.put "/api/board/screenshot/"?(id: Id), updateBoardScreenShot {.ok.}
  # result.put "/api/board/update/tags/"?(id: Id), updateBoardRelTags {.ok.}
  # result.delete "/api/board/"?(id: Id), deleteBoard {.ok.}

  # result.get "/api/tags/list/", listTags {.json: seq[Tag].}
  # result.post "/api/tag/new/", newTag {.Id.}
  # result.put "/api/tag/update/"?(id: Id), updateTag {.ok.}
  # result.delete "/api/tag/"?(id: Id), deleteTag {.ok.}

  # result.get "/api/palette/"?(name: string), getPalette {.json: seq[ColorTheme].}
  # result.get "/api/palettes/", listPalettes {.json: seq[Palette].}
  # result.put "/api/update/palette/"?(name: string), updatePalette {.json: Palette.}
  # result.# post "/api/palette/new/"?(name: string),
  # result.# put "/api/palette/update/"?(name: string),
  # result.# delete "/api/palette/"?(name: string)

  # result.get ur"explore", 
  # result.post "/api/explore/notes/"?(offset: int, limit: int), exploreNotes {.json.}
  # result.post "/api/explore/boards/"?(offset: int, limit: int), exploreBoards {.json.}
  # result.post "/api/explore/assets/"?(offset: int, limit: int), exploreAssets {.json.}
  # result.get "/api/explore/users/"?(name: string, offset: int, limit: int)

  # # to aviod CORS
  # result.get "/api/utils/github/code/" , fetchGithubCode
  # result.get "/api/utils/link/preview/", fetchLinkPreivewData

proc runWebServer*(host: string, port: Port) {.noreturn.} =
  {.cast(gcsafe).}:
    var server = newServer(initRouter(), maxBodyLen = 5.Mb)
    serve server, port, host
