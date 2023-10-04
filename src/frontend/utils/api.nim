import std/[strutils, sequtils]
import std/[asyncjs, dom, jsformdata, jsffi]

import ../../backend/routes
import ../../backend/database/[models]
import ../../common/[types, datastructures, conventions]
import ../jslib/axios
import ./js


let formCfg = AxiosConfig[FormData]()

template wrapResp(body): untyped {.dirty.} =
    proc(r: AxiosResponse) =
        body


proc loginApi*(
    code: string,
    success: proc(),
    fail: proc() = noop
) =
    discard get_api_login_url(code)
    .getApi()
    .then(success)
    .catch(fail)

proc logoutApi*(
    success: proc(),
    fail: proc() = noop
) =
    discard get_api_logout_url()
    .getApi()
    .then(success)
    .catch(fail)

proc meApi*(
    success: proc(u: User),
    fail: proc() = noop
) =
    discard get_api_me_url()
    .getApi()
    .then(wrapResp success cast[User](r.data))
    .catch(fail)


proc apiGetBoard*(
    id: Id,
    success: proc(b: Board),
    fail: proc() = noop
) =
    discard get_api_board_url(id)
    .getApi()
    .then(wrapResp success cast[Board](r.data))
    .catch(fail)

proc apiDeleteBoard*(
    id: Id,
    success: proc(),
    fail: proc() = noop
) =
    discard delete_api_board_url(id)
    .deleteApi()
    .then(success)
    .catch(fail)


proc apiUpdateBoardTitle*(
    id: Id,
    title: string,
    success: proc(),
    fail: proc() = noop
) =
    discard put_api_board_title_url(id, title)
    .putApi()
    .then(success)
    .catch(fail)

proc apiUpdateBoardScrenshot*(
    id: Id,
    form: FormData, ## form cantaining picture
    success: proc(),
    fail: proc() = noop
) =
    discard put_api_board_screen_shot_url(id)
    .putform(form, formCfg)
    .then(success)
    .catch(fail)

proc apiUpdateBoardContent*(
    id: Id,
    data: JsObject, ## form cantaining picture
    success: proc(),
    fail: proc() = noop
) =
    discard put_api_board_content_url(id)
    .putApi(data)
    .then(success)
    .catch(fail)


proc apiGetNote*(
    id: Id,
    success: proc(n: NoteItemView),
    fail: proc() = noop
) =
    discard get_api_note_url(id)
    .getApi()
    .then(wrapResp success cast[NoteItemView](r.data))
    .catch(fail)

proc apiGetNoteContentQuery*(
    queryString: string, ## pattern: "id::path"
    success: proc(n: TreeNodeRaw[JsObject]),
    fail: proc() = noop
) =
    let
        pieces = queryString.split "::"
        id = Id parseInt pieces[0]
        path =
            if pieces.len == 1 or pieces[1] == "":
                default seq[int]
            else:
                pieces[1].split(",").map(parseInt)

    echo (id, path)
    discard get_api_note_content_query_url(id, path)
    .getApi()
    .then(wrapResp success cast[TreeNodeRaw[JsObject]](r.data))
    .catch(fail)

proc apiUpdateNoteContent*(
    id: Id,
    data: TreeNodeRaw[JsObject],
    success: proc(),
    fail: proc() = noop
) =
    discard put_api_notes_update_content_url(id)
    .putApi(cast[JsObject](data))
    .then(success)
    .catch(fail)

proc apiUpdateNoteTags*(
    id: Id,
    data: JsObject,
    success: proc(),
    fail: proc() = noop
) =
    discard put_api_notes_update_tags_url(id)
    .putApi(data)
    .then(success)
    .catch(fail)

proc apiDeleteNote*(
    id: Id,
    success: proc(),
    fail: proc() = noop
) =
    discard delete_api_note_url(id)
    .deleteApi()
    .then(success)
    .catch(fail)


proc apiUploadAsset*(
    form: FormData,
    success: proc(assetUrl: string),
    fail: proc() = noop
) =
    discard post_assets_upload_url()
    .postForm(form, formCfg)
    .then(wrapResp success get_asset_short_hand_url cast[Id](r.data))
    .catch(fail)


proc apiGetTagsList*(
    success: proc(ts: seq[Tag]),
    fail: proc() = noop
) =
    discard get_api_tags_list_url()
    .getApi()
    .then(wrapResp success cast[seq[Tag]](r.data))
    .catch(fail)

proc apiCreateNewTag*(
    t: Tag,
    success: proc(),
    fail: proc() = noop
) =
    discard post_api_tag_new_url()
    .postApi(forceJsObject t)
    .then(success)
    .catch(fail)

proc apiUpdateTag*(
    t: Tag,
    success: proc(),
    fail: proc() = noop
) =
    discard put_api_tag_update_url(t.id)
    .putApi(forceJsObject t)
    .then(success)
    .catch(fail)

proc apiDeleteTag*(
    id: Id,
    success: proc(),
    fail: proc() = noop
) =
    discard delete_api_tag_url(id)
    .deleteApi()
    .then(success)
    .catch(fail)


proc apiExploreNotes*(
    xqdata: ExploreQuery,
    success: proc(ns: seq[NoteItemView]),
    fail: proc() = noop
) =
    discard post_api_explore_notes_url()
    .postApi(forceJsObject xqdata)
    .then(wrapResp success cast[seq[NoteItemView]](r.data))
    .catch(fail)

proc apiExploreBoards*(
    xqdata: ExploreQuery,
    success: proc(bs: seq[BoardItemView]),
    fail: proc() = noop
) =
    discard post_api_explore_boards_url()
    .postApi(forceJsObject xqdata)
    .then(wrapResp success cast[seq[BoardItemView]](r.data))
    .catch(fail)

proc apiExploreAssets*(
    xqdata: ExploreQuery,
    success: proc(ns: seq[AssetItemView]),
    fail: proc() = noop
) =
    discard post_api_explore_assets_url()
    .postApi(forceJsObject xqdata)
    .then(wrapResp success cast[seq[AssetItemView]](r.data))
    .catch(fail)

proc apiExploreUsers*(
    name: string,
    success: proc(us: seq[User]),
    fail: proc() = noop
) =
    discard get_api_explore_users_url(name)
    .getApi()
    .then(wrapResp success cast[seq[User]](r.data))
    .catch(fail)


proc apiGetPalette*(
    name: string,
    success: proc(cts: seq[ColorTheme]),
    fail: proc() = noop
) =
    discard get_api_palette_url(name)
    .getApi
    .then(wrapResp success cast[seq[ColorTheme]](r.data))
    .catch(fail)

proc apiGetGithubCode*(
    url: string,
    success: proc(cts: GithubCodeEmbed),
    fail: proc() = noop
) =
    discard get_api_utils_github_code_url(url)
    .getApi
    .then(wrapResp success cast[GithubCodeEmbed](r.data))
    .catch(fail)


proc apiGetLinkPreviewData*(
    url: string,
    success: proc(cts: LinkPreviewData),
    fail: proc() = noop
) =
    discard get_api_utils_link_preview_url(url)
    .getApi
    .then(wrapResp success cast[LinkPreviewData](r.data))
    .catch(fail)

