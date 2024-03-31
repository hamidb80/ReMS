import std/[options, sequtils, tables, algorithm, random]
import std/[dom, jsffi, asyncjs, jsformdata]

import karax/[karax, karaxdsl, vdom, vstyles]
import questionable
import caster

import ../components/[snackbar, simple, pro]
import ../utils/[browser, js, api]
import ../jslib/[axios]
import ../../common/[iter, types, datastructures, conventions, str]
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
    asTagSettings

  SearchableClass = enum
    scUsers = "users"
    scNotes = "notes"
    scBoards = "boards"
    scAssets = "assets"

const maxItems = 30
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


type AppState2 = enum
  asInit
  asSelectIcon

var
  tagsList: seq[Tag]
  tagState = asInit
  selectedTagI = noIndex
  currentTag = none Tag
  colors: seq[ColorTheme]

const
  ttt = staticRead "./icons.txt"

let
  icons = splitlines ttt
  defaultIcon = icons[0]


proc dummyTag: Tag =
  result = Tag(
    icon: defaultIcon,
    theme: colors[0], # sample colors,
    show_name: true,
    is_private: false,
    value_type: rvtNone,
    label: "name")

proc onIconSelected(icon: string) =
  currentTag.get.icon = icon
  tagState = asInit

proc genChangeSelectedTagi(i: int): proc() =
  proc =
    if selectedTagI == i:
      selectedTagI = noIndex
      currentTag = some dummyTag()
    else:
      selectedTagI = i
      currentTag = some tagsList[i]

proc iconSelectionBlock(icon: string, setIcon: proc(icon: string)): VNode =
  buildHtml:
    tdiv(class = "btn btn-lg btn-outline-dark rounded-2 m-1 p-2"):
      if icon.len > 0 and isAscii icon[0]:
        icon " m-2 " & icon
      else:
        span:
          text icon
      proc onclick =
        setIcon icon


func iconClass(sc: SearchableClass): string =
  case sc
  of scUsers: "fa-users"
  of scNotes: "fa-note-sticky"
  of scBoards: "fa-diagram-project"
  of scAssets: "fa-file"

proc loadMsg(n: NoteItemView): Future[void] =
  newPromise proc(resolve, reject: proc()) =
    deserizalize(compTable, n.data).dthen proc(t: TwNode) =
      msgCache[n.id] = t.dom.innerHtml
      resolve()

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

proc resolveNote(n: NoteItemView) =
  n.loadMsg.dthen proc =
    redraw()

proc resolveNotes =
  for n in notes:
    resolveNote n

  messagesResolved = true

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
    apiGetTagsList proc(ts: seq[Tag]) =
      tagsList = ts
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
              tagViewC tags, r.label, r.value, noop

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
  let
    inner = buildHtml:
      tdiv(class = "tw-content"):
        if n.id in msgCache:
          verbatim msgCache[n.id]
        else:
          text "loading..."

    deleteIcon =
      if n.id in wantToDelete: "fa-exclamation-circle"
      else: "fa-trash"

  proc copyNoteId =
    copyToClipboard $n.id

  proc goToTagManager =
    selectedNoteId = n.id
    selectedNoteIndex = i
    currentRels = n.rels
    activeRelTagIndex = noIndex
    appState = asTagManager

  proc deleteAct =
    if n.id in wantToDelete:
      deleteNote n.id
    else:
      add wantToDelete, n.id

  var btns = @[
    generalCardBtnLink("fa-glasses", "info", get_note_preview_url n.id),
    generalCardBtnAction("fa-sync", "primary", proc = resolveNote n),
    generalCardBtnAction("fa-copy", "primary", copyNoteId)]

  if issome me:
    add btns, [
      generalCardBtnAction("fa-tags", "success", goToTagManager),
      generalCardBtnLink("fa-pen", "warning", get_note_editor_url n.id),
      generalCardBtnAction(deleteIcon, "danger", deleteAct)]

  generalCardView "", inner, n.rels, tags, btns

proc boardItemViewC(b: BoardItemView): VNode =
  let
    inner = buildHtml:
      h3(dir = "auto"):
        text b.title

    url =
      if issome b.screenshot:
        get_asset_short_hand_url get b.screenshot
      else:
        ""

    deleteIcon =
      if b.id in wantToDelete: "fa-exclamation-circle"
      else: "fa-trash"

  proc deleteBoardAct =
    if b.id in wantToDelete:
      deleteBoard b.id
      discard fetchBoards()
    else:
      add wantToDelete, b.id


  var btns = @[
    generalCardBtnLink("fa-eye", "info", get_board_edit_url b.id)]

  if issome me:
    add btns, generalCardBtnAction(deleteIcon, "danger", deleteBoardAct)

  generalCardView url, inner, b.rels, tags, btns


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
            let val =
              if hasValue t: "..."
              else: ""
            tagViewC t, val, genAddTagToList t.label
          tagViewC defaultTag "...", "", genAddTagToList "..."

      h3(class = "mt-4"):
        text "Current Tags"

      tdiv(class = "card"):
        tdiv(class = "card-body"):
          for index, r in currentRels:
            tagViewC tags, r.label, r.value, genActiveTagClick index

      if activeRelTagIndex != noIndex:
        let
          r = currentRels[activeRelTagIndex]
          exists = r.label in tags

        if not exists:
          input(`type` = "text", class = "form-control",
            placeholder = "name",
            value = r.label):
            proc oninput(e: Event, v: Vnode) =
              currentRels[activeRelTagIndex].label = e.target.value


        if (not exists) or (hasValue tags[r.label]):
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

proc genAddSearchCriteriaImpl(tc: TagCriteria): proc() =
  proc =
    add searchCriterias, tc
    selectedCriteriaI = searchCriterias.high

proc genAddSearchCriteria(lbl, val: Str): proc() =
  genAddSearchCriteriaImpl TagCriteria(
    label: lbl,
    valuetype: rvtNone,
    operator: qoExists,
    value: val)

proc genAddSearchCriteria(t: Tag): proc() =
  genAddSearchCriteriaImpl TagCriteria(
    label: t.label,
    valuetype: t.valuetype,
    operator: qoExists,
    value: "")

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

        tdiv(class = "mx-4 btn btn-outline-white"):
          proc onclick =
            appState = asTagSettings
          icon "fa-cog fa-xl"

      tdiv(class = "card"):
        tdiv(class = "card-body"):
          for id, t in tags:
            let val =
              if hasValue t: "..."
              else: ""
            tagViewC t, val, genAddSearchCriteria t
          tagViewC defaultTag "...", "", genAddSearchCriteria("...", "")

      h3(class = "mt-4"):
        text "Current Criterias"

      tdiv(class = "card"):
        tdiv(class = "card-body"):
          for i, cr in searchCriterias:
            tdiv:
              let vtype =
                if cr.label in tags: tags[cr.label].valueType
                else: rvtNone

              text "@ "
              span(onclick = genRoundOperator(i, vtype)):
                text $cr.operator
              tagViewC tags, cr.label, cr.value, genSelectCriteria i
              if selectedSortCriteriaI == i:
                case sortOrder
                of Descending:
                  icon "fa-arrow-up-short-wide"
                of Ascending:
                  icon "fa-arrow-down-short-wide"

      if selectedCriteriaI != noIndex:
        let
          cr = searchCriterias[selectedCriteriaI]
          exists = cr.label in tags
          hasValue =
            if exists: hasValue tags[cr.label]
            else: true

        input(`type` = "text", class = "form-control",
          placeholder = "label ...",
          value = cr.label):
          proc oninput(e: Event, v: Vnode) =
            searchCriterias[selectedCriteriaI].label = e.target.value

        if hasValue:
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
          a(class = "btn btn-outline-primary", href = get_profile_url()):
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
                tdiv(class = "mb-3")

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

      of asTagSettings:
        tdiv(class = "p-4 mx-4 my-2"):
          h6(class = "mb-3"):
            icon "fa-bars-staggered me-2"
            text "All Tags"

          tdiv(class = "d-flex flex-row flex-wrap"):
            for i, t in tagsList:
              let val =
                if hasValue t: "..."
                else: ""
              tagViewC t, val, genChangeSelectedTagi i

        tdiv(class = "p-4 mx-4 my-2"):
          h6(class = "mb-3"):
            icon "fa-gear me-2"
            text "Config"

          tdiv(class = "form-control"):
            case tagState
            of asSelectIcon:
              tdiv(class = "input-group mb-4"):
                iconSelectionBlock($currentTag.get.icon, onIconSelected)

                input(`type` = "text", class = "form-control",
                  placeholder = "icon class or emoji",
                  value = currentTag.get.icon):
                  proc oninput(e: Event, v: Vnode) =
                    currentTag.get.icon = e.target.value

              tdiv(class = "d-flex flex-row flex-wrap justify-content-between"):
                for c in icons:
                  iconSelectionBlock($c, onIconSelected)

            of asInit:
              # name
              tdiv(class = "form-group d-inline-block mx-2"):
                label(class = "form-check-label"):
                  text "name: "

                input(`type` = "text", class = "form-control tag-input",
                    value = currentTag.get.label):
                  proc oninput(e: Event, v: Vnode) =
                    currentTag.get.label = e.target.value

              # icon
              tdiv(class = "form-check"):
                label(class = "form-check-label"):
                  text "icon: "

                tdiv(class = "d-inline-block"):
                  iconSelectionBlock $currentTag.get.icon, proc(s: string) =
                    tagState = asSelectIcon

              tdiv(class = "form-check form-switch"):
                checkbox currentTag.get.is_private, proc (b: bool) =
                  currentTag.get.is_private = b

                label(class = "form-check-label"):
                  text "is private"

              tdiv(class = "form-check form-switch"):
                checkbox currentTag.get.show_name, proc (b: bool) =
                  currentTag.get.show_name = b

                label(class = "form-check-label"):
                  text "show name"

              # has value
              tdiv(class = "form-check form-switch"):
                checkbox currentTag.get.hasValue, proc (b: bool) =
                  currentTag.get.value_type =
                    if b: rvtStr
                    else: rvtNone

                label(class = "form-check-label"):
                  text "has value"

              # value type
              tdiv(class = "form-group my-2"):
                label(class = "form-label"):
                  text "value type"

                select(class = "form-select",
                    disabled = not currentTag.get.hasValue):
                  for lbl in rvtStr..rvtDate:
                    option(value = cstr lbl.ord,
                        selected = currentTag.get.value_type == lbl):
                      text $lbl

                  proc onInput(e: Event, v: Vnode) =
                    currentTag.get.value_type = RelValueType parseInt e.target.value

              # background
              tdiv(class = "form-group d-inline-block mx-2"):
                label(class = "form-check-label"):
                  text "background color: "

                input(`type` = "color",
                    class = "form-control",
                    value = toColorString currentTag.get.theme.bg):
                  proc oninput(e: Event, v: Vnode) =
                    currentTag.get.theme.bg = parseHexColorPack $e.target.value

              # foreground
              tdiv(class = "form-group d-inline-block mx-2"):
                label(class = "form-check-label"):
                  text "foreground color: "

                input(`type` = "color",
                    class = "form-control",
                    value = toColorString currentTag.get.theme.fg):
                  proc oninput(e: Event, v: Vnode) =
                    currentTag.get.theme.fg = parseHexColorPack $e.target.value

              tdiv(class = "my-2"):
                let
                  t = get currentTag
                  val =
                    if t.hasValue: "..."
                    else: ""
                tagViewC get currentTag, val, noop

            if selectedTagI == noIndex:
              button(class = "btn btn-success w-100 mt-2 mb-4"):
                text "add"
                icon "mx-2 fa-plus"

                proc onclick =
                  apiCreateNewTag currentTag.get, proc =
                    notify "tag created"
                    waitAll [fetchTags()], proc = redraw()

            else:
              button(class = "btn btn-primary w-100 mt-2"):
                text "update"
                icon "mx-2 fa-sync"

                proc onclick =
                  apiUpdateTag currentTag.get, proc =
                    notify "tag updated"
                    waitAll [fetchTags()], proc = redraw()

              button(class = "btn btn-danger w-100 mt-2 mb-4"):
                text "delete"
                icon "mx-2 fa-trash"

                proc onclick =
                  apiDeleteTag currentTag.get.id, proc =
                    notify "tag deleted"
                    waitAll [fetchTags()], proc = redraw()

            button(class = "btn btn-warning w-100 mt-2 mb-4"):
              icon "fa-hand mx-2"
              text "close"

              proc onclick =
                appState = asNormal


proc fetchDefaultPalette: Future[void] =
  newPromise proc(resolve, reject: proc()) =
    apiGetPalette "default", proc(cs: seq[ColorTheme]) =
      colors = cs
      currentTag = some dummyTag()
      resolve()

when isMainModule:
  randomize()
  setRenderer createDom

  columnsCount =
    case screenOrientation()
    of soPortrait: 1
    of soLandscape: 2

  meApi proc (u: User) =
    me = some u
    redraw()

  waitAll [fetchTags(), fetchUsers(),
    fetchNotes(), fetchBoards(), fetchAssets(), fetchDefaultPalette()], proc =
    currentTag = some dummyTag()
    redraw()

  document.body.addEventListener "paste":
    proc(e: Event as ClipboardEvent) {.caster.} =
      case selectedClass
      of scAssets:
        pushUploads e.clipboardData.filesArray
        redraw()
      else:
        discard
