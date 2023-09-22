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


proc apiGetPallete*(
    name: string,
    success: proc(cts: seq[ColorTheme]),
    fail: proc() = noop
) =
    discard getApi(get_palette_url name)
    .then(wrapResp success cast[seq[ColorTheme]](r.data))
    .catch(fail)


proc apiGetBoardsList*(
    success: proc(bs: seq[BoardPreview]),
    fail: proc() = noop
) =
    discard get_api_boards_list_url()
    .getApi()
    .then(wrapResp success cast[seq[BoardPreview]](r.data))
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

proc apiCreateNewBoard*(
    success: proc(id: Id),
    fail: proc() = noop
) =
    discard post_api_boards_new_url()
    .postApi()
    .then(wrapResp success cast[Id](r.data))
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
    discard put_api_board_update_url(id)
    .putApi(data)
    .then(success)
    .catch(fail)


proc apiGetNotesList*(
    success: proc(ns: seq[Note]),
    fail: proc() = noop
) =
    discard get_api_notes_list_url()
    .getApi()
    .then(wrapResp success cast[seq[Note]](r.data))
    .catch(fail)

proc apiGetNote*(
    id: Id,
    success: proc(n: Note),
    fail: proc() = noop
) =
    discard get_api_note_url(id)
    .getApi()
    .then(wrapResp success cast[Note](r.data))
    .catch(fail)

proc apiUpdateNote*(
    id: Id,
    data: TreeNodeRaw[NativeJson],
    success: proc(),
    fail: proc() = noop
) =
    discard put_api_notes_update_url(id)
    .putApi(cast[JsObject](data))
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

proc apiCreateNewNote*(
    success: proc(id: Id),
    fail: proc() = noop
) =
    discard post_api_notes_new_url()
    .postApi()
    .then(wrapResp success cast[Id](r.data))
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
