import std/[strformat]

import ../common/types
import ./utils/web


defUrl "home", "/"
defUrl "dist", "/dist/" ? (file: string)

defUrl "sign-in",                "/sign-in/"
defUrl "sign-up",                "/sign-up/"
defUrl "my-profile",             "/api/profile/me/"

defUrl "profile",                "/profile/"               ? (uid: Id)
defUrl "update-profile",         "/api/profile/update/"

defUrl "upload-asset",           "/assets/upload/"
defUrl "download-asset",         "/assets/download/"       ? (id: Id)
defUrl "asset-shorthand",        "/a"
func get_asset_short_hand_url*(asset_id: Id): string =     fmt"/a?{asset_id}"
defUrl "asset-preview",          "/asset/preview/"         ? (id: Id)
defUrl "asset-info",             "/api/asset/"             ? (id: Id)
defUrl "update-asset-name",      "/api/asset/update/name/" ? (id: Id)
defUrl "update-asset-tags",      "/api/asset/update/tags/" ? (id: Id)
defUrl "delete-asset",           "/api/asset/"             ? (id: Id)

defUrl "new-note",               "/notes/new/"
defUrl "note-editor",            "/note/editor/"              ? (id: Id)
defUrl "note-preview",           "/note/preview/"             ? (id: Id)
defUrl "new-note-api",           "/api/note/new/"
defUrl "get-note",               "/api/note/"                 ? (id: Id)
defUrl "reference-another-note", "/api/note/content/query/"   ? (id: Id, path: seq[int])
defUrl "update-note-content",    "/api/notes/update/content/" ? (id: Id)
defUrl "update-note-tags",       "/api/notes/update/tags/"    ? (id: Id)
defUrl "delete-note",            "/api/note/"                 ? (id: Id)

defUrl "new-board",                "/boards/new/"
defUrl "board-editor",             "/board/edit/"             ? (id: Id)
defUrl "get-board",                "/api/board/"              ? (id: Id)
defUrl "update-board-title",       "/api/board/title/"        ? (id: Id, title: string)
defUrl "update-board-content",     "/api/board/content/"      ? (id: Id)
defUrl "update-board-screenshot",  "/api/board/screenshot/"   ? (id: Id)
defUrl "update-board-tags",        "/api/board/update/tags/"  ? (id: Id)
defUrl "delete-board",             "/api/board/"              ? (id: Id)

defUrl "get-tag-list",      "/api/tags/list/"
defUrl "new-tag",           "/api/tag/new/"
defUrl "update-tag",        "/api/tag/update/"               ? (id: Id)
defUrl "delete-tag",        "/api/tag/"                      ? (id: Id)

defUrl "get-palette",       "/api/palette/"                  ? (name: string)
defUrl "get-all-palettes",  "/api/palettes/"
defUrl "updte-palette",     "/api/update/palette/"           ? (name: string)

  # api/palette/new/"?(name: string),
  # api/palette/update/"?(name: string),
  # "/api/palette/"?(name: string)

defUrl  "explore",            "/explore/"
defUrl  "explore-notes",      "/api/explore/notes/"  ? (offset: int, limit: int)
defUrl  "explore-boards",     "/api/explore/boards/" ? (offset: int, limit: int)
defUrl  "explore-assets",     "/api/explore/assets/" ? (offset: int, limit: int)
defUrl  "explore-users",      "/api/explore/users/"  ? (name: string, offset: int, limit: int)

# to aviod CORS
defUrl "get-github-code", "/api/utils/github/code/"  ? (url: string)
defUrl "link-preview",    "/api/utils/link/preview/" ? (url: string)

