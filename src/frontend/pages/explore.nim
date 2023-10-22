import std/[options, sequtils, tables, algorithm]
import std/[dom, jsconsole, jsffi, asyncjs, jsformdata]

import karax/[karax, karaxdsl, vdom, vstyles]
import questionable
import caster

import ../components/[snackbar]
import ../utils/[browser, js, ui, api]
import ../jslib/[axios]
import ../../common/[iter, types, datastructures, conventions]
import ../../backend/routes
import ../../backend/database/[models]
import ./editor/[core, components]


# TODO add tags for boards
# TODO hide admin buttons for normal users
# TODO add pagination
# TODO add confirmation for deletation | the icon of delete button changes to check

type
  UploadStatus = enum
    usInProgress
    usFailed
    usCancelled
    usCompleted

  Upload = ref object
    name: cstring
    status: UploadStatus
    progress: Percent
    file: DFile
    promise: Future[AxiosResponse]
    reason: cstring

  AppState = enum
    asNormal
    asTagManager

  SearchableClass = enum
    scUsers = "users"
    scNotes = "notes"
    scBoards = "boards"
    scAssets = "assets"

  RelTagPath = tuple[tagid: Id, index: int]


let compTable = defaultComponents()
var
  appState = asNormal
  tags: Table[Id, Tag]
  msgCache: Table[Id, cstring]
  notes: seq[NoteItemView]
  boards: seq[BoardItemView]
  searchCriterias: seq[TagCriteria]
  selectedSortCriteriaI = noIndex
  sortOrder = Descending
  selectedCriteriaI = noIndex
  columnsCount = 1
  selectedClass = scUsers
  currentRelTags: Table[Id, seq[cstring]]
  selectedNoteId: Id
  selectedNoteIndex = noIndex
  activeRelTag = none RelTagPath
  userSearchStr = ""
  users: seq[User]
  assets: seq[AssetItemView]
  uploads: seq[Upload]
  selectedAssetIndex: int = -1 # noIndex
  assetNameTemp = c""



func toJson(s: Table[Id, seq[cstring]]): JsObject =
  result = newJsObject()
  for k, v in s:
    result[cstr int k] = v

func fromJson(s: RelValuesByTagId): Table[Id, seq[cstring]] =
  for k, v in s:
    let id = Id parseInt k
    result[id] = v



proc fetchAssets =
  apiExploreAssets ExploreQuery(), proc(ass: seq[AssetItemView]) =
    assets = ass

proc startUpload(u: Upload) =
  var
    form = toForm(u.name, u.file)
    cfg = AxiosConfig[FormData]()

  cfg.onUploadProgress = proc(pe: ProgressEvent) =
    u.progress = pe.loaded / pe.total * 100
    redraw()

  u.promise = postForm(post_assets_upload_url(), form, cfg)

  u.promise.dthen proc(r: AxiosResponse) =
    u.status = usCompleted
    fetchAssets()
    redraw()

  u.promise.dcatch proc(r: AxiosResponse) =
    u.status = usFailed
    u.reason = cast[cstring](r.data)
    redraw()

  u.status = usInProgress
  redraw()

proc cancelUpload(u: Upload) =
  # https://stackoverflow.com/questions/38329209/how-to-cancel-abort-ajax-request-in-axios
  discard

proc pushUploads(files: seq[DFile]) =
  for f in files:
    let u = Upload(
      name: f.name,
      status: usInProgress,
      progress: 0.0,
      file: f)

    startUpload u
    add uploads, u

# ----- Events

proc dropHandler(ev: Event as DragEvent) {.caster.} =
  pushUploads ev.dataTransfer.filesArray

proc clipboardHandler(e: Event as ClipboardEvent) {.caster.} =
  pushUploads e.clipboardData.filesArray

proc genCopy(url: cstring): proc =
  proc =
    copyToClipboard url

proc genSelectAsset(a: AssetItemView, i: int): proc =
  proc =
    selectedAssetIndex = i
    assetNameTemp = a.name

# ----- UI

func statusColor(status: UploadStatus): cstring =
  case status
  of usInProgress: "bg-primary"
  of usFailed: "bg-danger"
  of usCancelled: "bg-warning"
  of usCompleted: "bg-success"

func progressbar(percent: Percent, status: UploadStatus): Vnode =
  let cond = status == usInProgress

  buildHtml:
    tdiv(class = "progress limited-progress"):
      tdiv(
        class = "progress-bar " &
          statusColor(status) &
          iff(cond, "progress-bar-striped progress-bar-animated"),
        style = style(
          StyleAttr.width,
          $iff(cond, percent, 100) & "%"))


proc uploadStatusBtn(u: Upload): VNode =
  buildHtml:
    case u.status
    of usInProgress:
      button(class = "ms-2 btn btn-outline-primary rounded"):
        icon "fa-times"

    of usFailed:
      button(class = "ms-2 btn btn-outline-danger rounded"):
        icon "fa-sync"

        proc onclick =
          startUpload u

    of usCancelled:
      button(class = "ms-2 btn btn-outline-warning rounded"):
        icon "fa-sync"

    of usCompleted:
      button(class = "ms-2 btn btn-outline-success rounded"):
        icon "fa-check"

    # TODO show error message as a tooltip


proc genAssetDelete(id: Id, index: int): proc() =
  proc =
    apiDeleteAsset id, proc =
      notify "asset deleted!"
      delete assets, index

proc genAssetEditTags(a: AssetItemView, i: int): proc() =
  proc =
    currentRelTags = fromJson a.activeRelsValues
    appState = asTagManager

proc genAssetApplyBtn(id: Id, index: int): proc() =
  proc =
    apiUpdateAssetName id, $assetNameTemp, proc =
      assets[index].name = assetNameTemp
      notify "name updated"


proc assetFocusedComponent(a: AssetItemView, previewLink: string,
    index: int): VNode =
  buildHtml:
    tdiv(class = "px-3 py-2 d-flex justify-content-between border"):
      tdiv(class = "d-flex flex-column"):
        input(`type` = "text", class = "form-control", value = assetNameTemp):
          proc oninput(e: Event, v: Vnode) =
            assetNameTemp = e.target.value

      tdiv(class = "d-flex flex-row"):
        tdiv(class = "d-flex flex-column justify-content-start"):
          button(class = "mx-2 my-1 btn btn-outline-success",
              onclick = genAssetEditTags(a, index)):
            span: text "tags"
            icon "fa-tags ms-2"

          button(class = "mx-2 my-1 btn btn-outline-danger",
              onclick = genAssetDelete(a.id, index)):
            span: text "delete"
            icon "fa-close ms-2"

        tdiv(class = "d-flex flex-column justify-content-start"):
          button(class = "mx-2 my-1 btn btn-outline-dark"):
            icon "fa-chevron-up"
            proc onclick =
              selectedAssetIndex = -1

          button(class = "mx-2 my-1 btn btn-outline-dark",
              onclick = genCopy(previewLink)):
            span: text "copy link"
            icon "fa-copy ms-2"

          button(class = "mx-2 my-1 btn btn-outline-primary",
              onclick = genAssetApplyBtn(a.id, index)):
            span: text "apply"
            icon "fa-check ms-2"

proc userItemC(u: User): VNode =
  buildHTML:
    tdiv(class = "list-group-item list-group-item-action d-flex justify-content-between align-items-center"):
      bold(class = "mx-2"):
        a(target = "_blank"):
          text "@"
          text u.username

      span(class = "text-muted fst-italic"):
        text u.nickname

proc assetItemComponent(index: int, a: AssetItemView,
    previewLink: string): Vnode =
  buildHtml:
    tdiv(class = "list-group-item list-group-item-action d-flex justify-content-between align-items-center"):
      tdiv:
        span:
          text "#"
          text $a.id

        bold(class = "mx-2"):
          a(target = "_blank", href = previewLink):
            text a.name

        span(class = "text-muted fst-italic"):
          text "("
          text $a.size.int
          text " B)"

      tdiv(class = "d-flex flex-row align-items-center"):
        tdiv:
          for k, values in a.activeRelsValues:
            for v in values:
              let id = Id parseInt k
              tagViewC tags[id], v, noop

        button(class = "mx-2 btn btn-outline-dark",
            onclick = genSelectAsset(a, index)):
          icon "fa-chevron-down"

proc assetUploader: VNode =
  buildHTML:
    tdiv(class = ""):
      h6(class = "mb-3"):
        icon("fa-arrow-pointer me-2")
        text "Select / Paste / Drag"

      tdiv(class = "rounded p-3 rounded bg-white d-flex flex-column align-items-center justify-content-center"):
        tdiv(class = "form-group w-100"):
          input(class = "form-control",
              `type` = "file",
              multiple = "multiple",
              placeholder = "select as many as files you want!"):

            proc onInput(e: Event, v: VNode) =
              pushUploads e.currentTarget.filesArray

        tdiv(class = "my-3")

        tdiv(class = """dropper bg-light border-secondary grab
              border border-4 border-dashed rounded-2 user-select-none
              d-flex flex-column justify-content-center align-items-center"""):

          tdiv():
            text "drag file or paste something here"

          tdiv():
            text "when hover"


          proc ondrop(e: Event, v: VNode) =
            e.preventdefault
            dropHandler e

          proc ondragover(e: Event, v: VNode) =
            e.preventdefault

      h6(class = "mt-4 mb-3"):
        tdiv(class = "d-flex flex-row justify-content-between align-items-center"):
          tdiv:
            if uploads.anyIt it.status == usInProgress:
              icon("fa-spinner fa-spin-pulse me-2")
            else:
              icon("fa-check-double me-2")

            text "in progress uploads"
          tdiv(class = "btn btn-outline-dark"):
            text "clear"
            icon "fa-trash-can ms-2"

            proc onclick =
              reset uploads

      tdiv(class = "list-group mb-4"):
        for u in uploads.ritems:
          tdiv(class = "d-flex flex-row align-items-center justify-content-between list-group-item list-group-item-action"):
            text u.name
            tdiv(class = "d-flex flex-row align-items-center justify-content-between"):
              progressbar u.progress, u.status
              uploadStatusBtn u



proc getExploreQuery: ExploreQuery =
  result = ExploreQuery(
    searchCriterias: searchCriterias,
    order: sortOrder)

  if selectedCriteriaI != noIndex:
    result.sortCriteria = somec searchCriterias[selectedCriteriaI]

proc fetchBoards: Future[void] =
  newPromise proc(resolve, reject: proc()) =
    apiExploreBoards getExploreQuery(), proc(bs: seq[BoardItemView]) =
      boards = bs
      resolve()

proc deleteBoard(id: Id) =
  apiDeleteBoard id, proc =
    discard fetchBoards()

proc fetchUsers: Future[void] =
  newPromise proc(resolve, reject: proc()) =
    apiExploreUsers userSearchStr, proc(us: seq[User]) =
      users = us
      resolve()

# TODO write a note laod manager component in a different file
proc loadMsg(n: NoteItemView) =
  deserizalize(compTable, n.data).dthen proc(t: TwNode) =
    msgCache[n.id] = t.dom.innerHtml
    redraw()

proc fetchNotes: Future[void] =
  newPromise proc(resolve, reject: proc()) =
    apiExploreNotes getExploreQuery(), proc(ns: seq[NoteItemView]) =
      notes = ns
      for n in notes:
        loadMsg n
      resolve()

proc fetchTags(): Future[void] =
  newPromise proc(resolve, reject: proc()) =
    apiGetTagsList proc(tagsList: seq[Tag]) =
      for t in tagsList:
        tags[t.id] = t
      resolve()

proc deleteNote(id: Id) =
  apiDeleteNote id, proc =
    deleteIt notes, it.id == id
    redraw()

# ----- UI

proc columnCountSetter(i: int): proc() =
  proc =
    columnsCount = i

proc searchClassSetter(i: SearchableClass): proc() =
  proc =
    selectedClass = i

proc notePreviewC(n: NoteItemView, i: int): VNode =
  buildHtml:
    tdiv(class = "card my-3 masonry-item border rounded bg-white"):
      tdiv(class = "card-body"):
        tdiv(class = "tw-content"):
          if n.id in msgCache:
            verbatim msgCache[n.id]
          else:
            text "loading..."

      tdiv(class = "m-2"):
        for k, values in n.activeRelsValues:
          for v in values:
            let id = Id parseInt k
            tagViewC tags[id], v, noop

      tdiv(class = "card-footer d-flex justify-content-center"):

        a(class = "btn mx-1 btn-compact btn-outline-info", target = "_blank",
            href = get_note_preview_url(n.id)):
          icon "fa-glasses"

        button(class = "btn mx-1 btn-compact btn-outline-primary"):
          icon "fa-copy"
          proc onclick =
            copyToClipboard $n.id

        button(class = "btn mx-1 btn-compact btn-outline-success"):
          icon "fa-tags"

          proc onclick =
            selectedNoteId = n.id
            selectedNoteIndex = i
            currentRelTags = fromJson n.activeRelsValues
            appState = asTagManager

        a(class = "btn mx-1 btn-compact btn-outline-warning",
            href = get_note_editor_url(n.id)):
          icon "fa-pen"

        button(class = "btn mx-1 btn-compact btn-outline-danger"):
          icon "fa-close"

          proc onclick =
            deleteNote n.id

proc boardItemViewC(b: BoardItemView): VNode =
  buildHtml:
    tdiv(class = "masonry-item card my-3 border rounded bg-white"):
      if issome b.screenshot:
        tdiv(class = "d-flex bg-light card-img justify-content-center overflow-hidden"):
          img(src = get_asset_short_hand_url b.screenshot.get)

      tdiv(class = "card-body"):
        h3(dir = "auto"):
          text b.title

      tdiv(class = "card-footer d-flex justify-content-center"):
        a(class = "btn mx-1 btn-compact btn-outline-warning",
            href = get_board_edit_url b.id):
          icon "fa-pen"

        a(class = "btn mx-1 btn-compact btn-outline-danger"):
          icon "fa-close"

          proc onclick(e: Event, v: Vnode) =
            deleteBoard b.id
            redirect ""

proc genAddTagToList(id: Id): proc() =
  proc =
    add currentRelTags, id, c""

proc genActiveTagClick(tagId: Id, index: int): proc() =
  proc =
    activeRelTag = some (tagid, index)

# TODO make it globally available

proc relTagManager(): Vnode =
  buildHTML:
    tdiv:
      h3(class = "mt-4"):
        text "Available Tags"

      tdiv(class = "card"):
        tdiv(class = "card-body"):
          for id, t in tags:
            if id notin currentRelTags or t.can_be_repeated:
              tagViewC t, "val", genAddTagToList id

      h3(class = "mt-4"):
        text "Current Tags"

      tdiv(class = "card"):
        tdiv(class = "card-body"):
          for id, vals in currentRelTags:
            for index, v in vals:
              tagViewC tags[id], v, genActiveTagClick(id, index)

      if path =? activeRelTag:
        let t = tags[path.tagid]
        if t.hasValue:
          input(`type` = "text", class = "form-control",
            placeholder = "value ...",
            value = currentRelTags[path.tagid][path.index], ):
            proc oninput(e: Event, v: Vnode) =
              currentRelTags[path.tagid][path.index] = e.target.value

        button(class = "btn btn-danger w-100 mt-2 mb-4"):
          text "remove"
          icon "mx-2 fa-close"

          proc onclick =
            reset activeRelTag

            del currentRelTags[path.tagid], path.index
            if currentRelTags[path.tagid].len == 0:
              del currentRelTags, path.tagid


      button(class = "btn btn-primary w-100 mt-2"):
        text "save"
        icon "mx-2 fa-save"

        proc onclick =
          let d = toJson currentRelTags

          case selectedClass
          of scUsers: discard
          of scNotes:
            apiUpdateNoteTags selectedNoteId, d, proc =
              notify "changes applied"
              notes[selectedNoteIndex].activeRelsValues = cast[
                  RelValuesByTagId](d)

          of scBoards: discard
          of scAssets:
            apiUpdateAssetTags assets[selectedAssetIndex].id, d, proc =
              notify "changes applied"
              assets[selectedAssetIndex].activeRelsValues = cast[
                  RelValuesByTagId](d)


      button(class = "btn btn-warning w-100 mt-2 mb-4"):
        text "cancel"
        icon "mx-2 fa-hand"

        proc onclick =
          reset activeRelTag
          appState = asNormal

proc incRound[E: enum](i: var E) =
  i =
    if i == E.high: E.low
    else: succ i

proc genRoundOperator(i: int, vt: TagValueType): proc() =
  proc =
    incRound searchCriterias[i].operator


proc genAddSearchCriteria(t: Tag): proc() =
  proc =
    add searchCriterias, TagCriteria(
      tagid: t.id,
      label: t.label,
      valuetype: t.valuetype,
      operator: qoExists,
      value: "")

    selectedCriteriaI = searchCriterias.high

proc genSelectCriteria(i: int): proc() =
  proc =
    if selectedCriteriaI == i:
      if selectedSortCriteriaI == i:
        case sortOrder
        of Descending:
          sortOrder = Ascending
        of Ascending:
          sortOrder = Descending
          selectedSortCriteriaI = noIndex
          selectedCriteriaI = noIndex
      else:
        selectedSortCriteriaI = i
    else:
      selectedCriteriaI = i

proc searchTagManager(): Vnode =
  buildHTML:
    tdiv:
      h3(class = "mt-4"):
        text "Available Tags"

      tdiv(class = "card"):
        tdiv(class = "card-body"):
          for id, t in tags:
            tagViewC t, "...", genAddSearchCriteria t

      h3(class = "mt-4"):
        text "Current Criterias"

      tdiv(class = "card"):
        tdiv(class = "card-body"):
          for i, cr in searchCriterias:
            tdiv:
              text "@ "
              span(onclick = genRoundOperator(i, tags[cr.tagid].valueType)):
                text $cr.operator
              tagViewC tags[cr.tagid], cr.value, genSelectCriteria i
              if selectedSortCriteriaI == i:
                case sortOrder
                of Descending:
                  icon "fa-arrow-up-short-wide"
                of Ascending:
                  icon "fa-arrow-down-short-wide"

      if selectedCriteriaI != noIndex:
        let
          cr = searchCriterias[selectedCriteriaI]
          tid = cr.tagid
          t = tags[tid]

        if t.hasValue:
          input(`type` = "text", class = "form-control",
            placeholder = "value ...",
            value = cr.value):
            proc oninput(e: Event, v: Vnode) =
              searchCriterias[selectedCriteriaI].value = e.target.value

        button(class = "btn btn-danger w-100 my-2"):
          text "remove"
          icon "mx-2 fa-close"

          proc onclick =
            if selectedCriteriaI == selectedSortCriteriaI:
              selectedCriteriaI = noIndex

            delete searchCriterias, selectedCriteriaI
            selectedCriteriaI = noIndex


proc createDom: Vnode =
  echo "just redrawn"

  result = buildHtml tdiv:
    snackbar()

    nav(class = "navbar navbar-expand-lg bg-white"):
      tdiv(class = "container-fluid"):
        a(class = "navbar-brand", href = "#"):
          icon "fa-search fa-xl me-3 ms-1"
          text "Explore"

    tdiv(class = "px-4 py-2 my-2"):
      case appState
      of asNormal:
        tdiv(class = "d-flex justify-content-around align-items-center flex-wrap my-4"):

          ul(class = "pagination pagination-lg"):
            for i in SearchableClass:
              li(class = "page-item " & iff(i == selectedClass, "active"),
                  onclick = searchClassSetter i):
                a(class = "page-link", href = "#"):
                  text $i

          ul(class = "pagination pagination-lg"):
            for i in 1..4:
              li(class = "page-item " & iff(i == columnsCount, "active"),
                  onclick = columnCountSetter i):
                a(class = "page-link", href = "#"):
                  text $i

        case selectedClass
        of scUsers:
          a(class = "btn btn-outline-primary w-100 mt-2", href = get_login_url()):
            text "login "
            icon "mx-2 fa-sign-in"

          input(`type` = "text", class = "form-control",
            placeholder = "id or name"):
            proc oninput(e: Event, v: Vnode) =
              userSearchStr = $e.target.value

        of scBoards:
          a(class = "btn btn-outline-primary w-100 mt-2",
              href = get_boards_new_url()):
            text "new "
            icon "mx-2 fa-plus"

          searchTagManager()

        of scNotes:
          a(class = "btn btn-outline-primary w-100 mt-2",
              href = get_notes_new_url()):
            text "new "
            icon "mx-2 fa-plus"

          searchTagManager()

        of scAssets:
          assetUploader()
          searchTagManager()

        tdiv(class = "my-1"):
          button(class = "btn btn-outline-info w-100 mt-2 mb-4"):
            text "search"
            icon "mx-2 fa-search"

            proc onclick =
              case selectedClass
              of scNotes: discard fetchNotes()
              of scBoards: discard fetchBoards()
              of scAssets:
                apiExploreAssets getExploreQuery(), proc(ass: seq[
                    AssetItemView]) =
                  assets = ass
                  redraw()

              of scUsers:
                discard fetchUsers()

          case selectedClass
          of scUsers:
            tdiv(class = "list-group my-4"):
              for u in users:
                userItemC u

          of scNotes:
            tdiv(class = "my-4 masonry-container masonry-" & $columnsCount):
              for i, n in notes:
                notePreviewC n, i

          of scBoards:
            tdiv(class = "my-4 masonry-container masonry-" & $columnsCount):
              for b in boards:
                boardItemViewC b

          of scAssets:
            tdiv(class = "list-group my-4"):
              for i, a in assets:
                let u = get_asset_short_hand_url a.id

                if i == selectedAssetIndex:
                  assetFocusedComponent a, u, i
                else:
                  assetItemComponent i, a, u

      of asTagManager:
        relTagManager()


when isMainModule:
  setRenderer createDom

  columnsCount =
    case screenOrientation()
    of soPortrait: 2
    of soLandscape: 3

  waitAll [fetchTags(), fetchNotes(), fetchBoards(), fetchUsers()], proc =
    redraw()

  document.body.addEventListener "paste":
    proc(e: Event as ClipboardEvent) {.caster.} =
      case selectedClass
      of scAssets:
        pushUploads e.clipboardData.filesArray
        redraw()
      else:
        discard
