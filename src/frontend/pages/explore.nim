import std/[options, sequtils, tables, algorithm]
import std/[dom, jsffi, asyncjs, jsformdata]

import karax/[karax, karaxdsl, vdom, vstyles]
import questionable
import caster

import ../components/[snackbar, ui]
import ../utils/[browser, js, api]
import ../jslib/[axios]
import ../../common/[iter, types, datastructures, conventions]
import ../../backend/routes
import ../../backend/database/[models, logic]
import ./editor/[core, components]


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

const maxItems = 20
let compTable = defaultComponents()
var
  me = none User
  lastPage: array[SearchableClass, Natural]
  appState = asNormal
  tags: Table[Str, Tag]
  msgCache: Table[Id, cstring]
  notes: seq[NoteItemView]
  boards: seq[BoardItemView]
  searchCriterias: seq[TagCriteria]
  selectedSortCriteriaI = noIndex
  sortOrder = Descending
  selectedCriteriaI = noIndex
  columnsCount = 1
  selectedClass = scUsers
  currentRels: seq[RelMinData]
  selectedNoteId: Id
  selectedNoteIndex = noIndex
  activeRelTagIndex = noIndex
  userSearchStr = ""
  users: seq[User]
  assets: seq[AssetItemView]
  uploads: seq[Upload]
  selectedAssetIndex: int = -1 # noIndex
  wantToDelete: seq[int]
  assetNameTemp = c""
  messagesResolved = true


func iconClass(sc: SearchableClass): string =
  case sc
  of scUsers: "fa-users"
  of scNotes: "fa-note-sticky"
  of scBoards: "fa-diagram-project"
  of scAssets: "fa-file"

proc loadMsg(n: NoteItemView) =
  deserizalize(compTable, n.data).dthen proc(t: TwNode) =
    msgCache[n.id] = t.dom.innerHtml

proc getExploreQuery: ExploreQuery =
  result = ExploreQuery(
    searchCriterias: searchCriterias,
    order: sortOrder)

  if selectedCriteriaI != noIndex:
    result.sortCriteria = somec searchCriterias[selectedCriteriaI]

proc fetchAssets: Future[void] =
  newPromise proc(resolve, reject: proc()) =
    let p = lastPage[scAssets]
    reset assets
    apiExploreAssets getExploreQuery(), p*maxItems, maxItems, 
      proc(ass: seq[AssetItemView]) =
        assets = ass
        resolve()
        redraw()

proc fetchBoards: Future[void] =
  newPromise proc(resolve, reject: proc()) =
    let p = lastPage[scBoards]
    reset boards
    apiExploreBoards getExploreQuery(), p*maxItems, maxItems, 
      proc(bs: seq[BoardItemView]) =
        boards = bs
        resolve()
        redraw()

proc resolveNotes =
  for n in notes:
    loadMsg n

  messagesResolved = true
  redraw()

proc fetchNotes: Future[void] =
  newPromise proc(resolve, reject: proc()) =
    let p = lastPage[scNotes]
    reset notes
    apiExploreNotes getExploreQuery(), p*maxItems, maxItems, 
      proc(ns: seq[NoteItemView]) =
        notes = ns
        messagesResolved = false

        if selectedClass == scNotes:
          resolveNotes()
        resolve()

proc fetchTags: Future[void] =
  newPromise proc(resolve, reject: proc()) =
    apiGetTagsList proc(tagsList: seq[Tag]) =
      for t in tagsList:
        tags[t.label] = t
      resolve()

proc fetchUsers: Future[void] =
  newPromise proc(resolve, reject: proc()) =
    let p = lastPage[scUsers]
    reset users
    apiExploreUsers userSearchStr, p*maxItems, maxItems, proc(us: seq[User]) =
      users = us
      resolve()
      redraw()


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
    discard fetchAssets().then proc =
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
    currentRels = a.rels
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

        if isAdmin u:
          icon "fa-user-shield ms-2"

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
          for r in a.rels:
            if r.label in tags:
              tagViewC tags[r.label], r.value, noop
            else:
              text r.label

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


proc deleteBoard(id: Id) =
  apiDeleteBoard id, proc =
    discard fetchBoards()

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
    if i == scNotes and not messagesResolved:
      resolveNotes()

    selectedClass = i
    reset wantToDelete

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
        for r in n.rels:
          tagViewC tags[r.label], r.value, noop

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
            currentRels = n.rels
            appState = asTagManager

        a(class = "btn mx-1 btn-compact btn-outline-warning",
            href = get_note_editor_url(n.id)):
          icon "fa-pen"

        button(class = "btn mx-1 btn-compact btn-outline-danger"):
          # TODO make buttons a separate component
          let icn =
            if n.id in wantToDelete: "fa-exclamation-circle"
            else: "fa-trash"

          icon icn

          proc onclick =
            echo n.id, wantToDelete, n.id in wantToDelete
            if n.id in wantToDelete:
              deleteNote n.id
            else:
              add wantToDelete, n.id

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

        button(class = "btn mx-1 btn-compact btn-outline-danger"):
          icon "fa-close"

          proc onclick(e: Event, v: Vnode) =
            deleteBoard b.id
            discard fetchBoards()

proc genAddTagToList(lbl: Str): proc() =
  proc =
    add currentRels, RelMinData(label: lbl, value: "")

proc genActiveTagClick(index: int): proc() =
  proc =
    activeRelTagIndex = index

proc relTagManager(): Vnode =
  buildHTML:
    tdiv:
      h3(class = "mt-4"):
        text "Available Tags"

      tdiv(class = "card"):
        tdiv(class = "card-body"):
          for id, t in tags:
            tagViewC t, "...", genAddTagToList t.label

      h3(class = "mt-4"):
        text "Current Tags"

      tdiv(class = "card"):
        tdiv(class = "card-body"):
          for index, r in currentRels:
            if r.label in tags:
              tagViewC tags[r.label], r.value, genActiveTagClick index
            else:
              span:
                text "# "
                text r.label

      if activeRelTagIndex != noIndex:
        let r = currentRels[activeRelTagIndex]
        if hasValue tags[r.label]:
          input(`type` = "text", class = "form-control",
            placeholder = "value ...",
            value = r.value):
            proc oninput(e: Event, v: Vnode) =
              currentRels[activeRelTagIndex].value = e.target.value

        button(class = "btn btn-danger w-100 mt-2 mb-4"):
          text "remove"
          icon "mx-2 fa-close"

          proc onclick =
            delete currentRels, activeRelTagIndex
            activeRelTagIndex = noIndex

      button(class = "btn btn-primary w-100 mt-2"):
        text "save"
        icon "mx-2 fa-save"

        proc onclick =
          let d = cast[JsObject](currentRels)

          case selectedClass
          of scUsers: discard
          of scBoards: discard

          of scNotes:
            apiUpdateNoteTags selectedNoteId, d, proc =
              notify "changes applied"
              notes[selectedNoteIndex].rels = currentRels
          
          of scAssets:
            apiUpdateAssetTags assets[selectedAssetIndex].id, d, proc =
              assets[selectedAssetIndex].rels = currentRels
              notify "changes applied"

      button(class = "btn btn-warning w-100 mt-2 mb-4"):
        text "cancel"
        icon "mx-2 fa-hand"

        proc onclick =
          reset activeRelTagIndex
          appState = asNormal

proc doSearch =
  case selectedClass
  of scNotes: discard fetchNotes()
  of scBoards: discard fetchBoards()
  of scAssets: discard fetchAssets()
  of scUsers: discard fetchUsers()


proc genRoundOperator(i: int, vt: RelValueType): proc() =
  proc =
    incRound searchCriterias[i].operator


proc genAddSearchCriteria(t: Tag): proc() =
  proc =
    add searchCriterias, TagCriteria(
      label: t.label,
      valuetype: t.valuetype,
      operator: qoExists,
      value: "")

    selectedCriteriaI = searchCriterias.high

proc genSelectCriteria(i: int): proc() =
  proc =
    if i == selectedCriteriaI:
      if i == selectedSortCriteriaI:
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
              span(onclick = genRoundOperator(i, tags[cr.label].valueType)):
                text $cr.operator
              tagViewC tags[cr.label], cr.value, genSelectCriteria i
              if selectedSortCriteriaI == i:
                case sortOrder
                of Descending:
                  icon "fa-arrow-up-short-wide"
                of Ascending:
                  icon "fa-arrow-down-short-wide"

      if selectedCriteriaI != noIndex:
        let
          cr = searchCriterias[selectedCriteriaI]
          t = tags[cr.label]

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

        if isNone me:
          a(class = "btn btn-outline-primary", href = get_login_url()):
            text "login "
            icon "mx-2 fa-sign-in"

    tdiv(class = "px-1 px-sm-2 px-md-3 px-lg-4-4 py-2 my-2"):
      case appState
      of asNormal:
        tdiv(class = "d-flex justify-content-around align-items-center flex-wrap my-4"):

          ul(class = "pagination pagination-lg"):
            for i in SearchableClass:
              li(class = "page-item " & iff(i == selectedClass, "active"),
                  onclick = searchClassSetter i):
                a(class = "page-link", href = "#"):
                  icon iconClass i
                  if soLandscape == screenOrientation():
                    span(class = "ms-2"):
                      text $i

          ul(class = "pagination pagination-lg"):
            for i in 1..4:
              li(class = "page-item " & iff(i == columnsCount, "active"),
                  onclick = columnCountSetter i):
                a(class = "page-link", href = "#"):
                  text $i

        case selectedClass
        of scUsers:
          input(`type` = "text", class = "form-control",
            placeholder = "id or name"):
            proc oninput(e: Event, v: Vnode) =
              userSearchStr = $e.target.value

        of scBoards:
          if issome me:
            a(class = "btn btn-outline-primary w-100 mt-2",
                href = get_boards_new_url()):
              text "new "
              icon "mx-2 fa-plus"

          searchTagManager()

        of scNotes:
          if issome me:
            a(class = "btn btn-outline-primary w-100 mt-2",
                href = get_notes_new_url()):
              text "new "
              icon "mx-2 fa-plus"

          searchTagManager()

        of scAssets:
          if issome me:
            assetUploader()
          searchTagManager()

        tdiv(class = "my-1"):
          button(class = "btn btn-outline-info w-100 mt-2 mb-4"):
            text "search"
            icon "mx-2 fa-search"

            proc onclick =
              reset lastPage
              doSearch()

          case selectedClass
          of scUsers:
            tdiv(class = "list-group my-4"):
              if u =? me:
                userItemC u
                tdiv(class="mb-3")

              for u in users:
                if (isNone me) or (u.username != me.get.username):
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

          tdiv(class = "d-flex justify-content-center align-items-center"):
            ul(class = "pagination pagination-lg"):

              li(class = "page-item"):
                a(class = "page-link", href = "#"):
                  icon "fa-angle-left"
                proc onclick =
                  if lastPage[selectedClass] > 0:
                    dec lastPage[selectedClass]
                    doSearch()

              li(class = "page-item"):
                tdiv(class = "page-link active"):
                  text $(lastPage[selectedClass] + 1)

              li(class = "page-item"):
                a(class = "page-link", href = "#"):
                  icon "fa-angle-right"
                proc onclick =
                  inc lastPage[selectedClass]
                  doSearch()

      of asTagManager:
        relTagManager()


when isMainModule:
  setRenderer createDom

  columnsCount =
    case screenOrientation()
    of soPortrait: 1
    of soLandscape: 2

  meApi proc (u: User) = 
    me = some u
    redraw()

  waitAll [fetchTags(), fetchUsers(), fetchNotes(), fetchBoards(), fetchAssets()], proc =
    redraw()

  document.body.addEventListener "paste":
    proc(e: Event as ClipboardEvent) {.caster.} =
      case selectedClass
      of scAssets:
        pushUploads e.clipboardData.filesArray
        redraw()
      else:
        discard
