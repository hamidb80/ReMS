import std/[strformat]

import ../common/types
import ./utils/web


func get_asset_short_hand_url*(asset_id: Id): string =
  "/a?" & $asset_id

defUrls:
  # config "[not found]"
  # config "[method not allowed]"
  # config "[error]"

  get "home", "/"
  get "dist", "/dist/"?(file: string)

  # get "/profile/"
  # post "/api/login/"?(kind: string)
  # get "/api/logout/"

  get  "my-profile",     "/api/profile/me/"
  get  "get-profile",    "/api/profile/"
  post "new-profile",    "/api/profile/new/"
  put  "update-profile", "/api/profile/update/"

  post   "upload-asset",      "/assets/upload/"
  get    "download-asset",    "/assets/download/"?(id: Id)
  get    "asset-shorthand",   "/a"
  get    "asset-preview",     "/asset/preview/"?(id: Id)
  get    "asset-info",        "/api/asset/"?(id: Id)
  get    "update-asset-name", "/api/asset/update/name/"
  put    "update-asset-tags", "/api/asset/update/tags/"
  delete "delete-asset",      "/api/asset/"?(id: Id)

  get    "new-note", "/notes/new/"
  get    "note-editor", "/note/editor/"?(id: Id)
  get    "note-preview", "/note/preview/"?(id: Id)
  get    "new-note-api", "/api/note/new/"
  get    "get-note", "/api/note/"?(id: Id)
  get    "reference-from-another-note", "/api/note/content/query/"?(id: Id, path: seq[int])
  put    "update-note-content", "/api/notes/update/content/"?(id: Id)
  put    "update-note-tags", "/api/notes/update/tags/"?(id: Id)
  delete "delete-note", "/api/note/"?(id: Id)

  get    "new-board", "/boards/new/"
  get    "board-editor", "/board/edit/"?(id: Id)
  get    "get-board", "/api/board/"?(id: Id)
  put    "update-board-title", "/api/board/title/"?(id: Id, title: string)
  put    "update-board-content", "/api/board/content/"?(id: Id)
  put    "update-board-screenshot", "/api/board/screenshot/"?(id: Id)
  put    "update-board-tags", "/api/board/update/tags/"?(id: Id)
  delete "delete-board", "/api/board/"?(id: Id)

  get    "get-tag-list", "/api/tags/list/"
  post   "new-tag",      "/api/tag/new/"
  put    "update-tag",   "/api/tag/update/"?(id: Id)
  delete "delete-tag",   "/api/tag/"?(id: Id)

  get    "get-palette",      "/api/palette/"?(name: string)
  get    "get-all-palettes", "/api/palettes/"
  put    "updte-palette",    "/api/update/palette/"?(name: string)
  # post "/api/palette/new/"?(name: string),
  # put "/api/palette/update/"?(name: string),
  # delete "/api/palette/"?(name: string)

  get  "explore",        "/explore/"
  post "explore-notes",  "/api/explore/notes/"?(offset: int, limit: int)
  post "explore-boards", "/api/explore/boards/"?(offset: int, limit: int)
  post "explore-assets", "/api/explore/assets/"?(offset: int, limit: int)
  get  "explore-users",  "/api/explore/users/"?(name: string, offset: int, limit: int)

  # to aviod CORS
  get "get-github-code", "/api/utils/github/code/"?(url: string)
  get "link-preview",    "/api/utils/link/preview/"?(url: string)

