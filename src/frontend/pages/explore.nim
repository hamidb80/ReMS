import std/[options, sequtils, tables]
import std/[dom, jsconsole, jsffi, asyncjs]

import karax/[karax, karaxdsl, vdom, vstyles]
import questionable

import ../components/[snackbar]
import ../utils/[browser, js, ui, api]
import ../../common/[iter, types, datastructures, conventions]
import ../../backend/routes
import ../../backend/database/[models]
import ./editor/[core, components]


type
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
  selectedCriteriaI = noIndex
  columnsCount = 3
  selectedClass = scUsers
  currentRelTags: Table[Id, seq[cstring]]
  selectedNoteId: Id
  selectedNoteIndex = noIndex
  activeRelTag = none RelTagPath


func toJson(s: Table[Id, seq[cstring]]): JsObject =
  result = newJsObject()
  for k, v in s:
    result[cstr int k] = v

func fromJson(s: RelValuesByTagId): Table[Id, seq[cstring]] =
  for k, v in s:
    let id = Id parseInt k
    result[id] = v

proc getExploreQuery: ExploreQuery =
  ExploreQuery(criterias: searchCriterias)

proc fetchBoards: Future[void] =
  newPromise proc(resolve, reject: proc()) =
    apiExploreBoards getExploreQuery(), proc(bs: seq[BoardItemView]) =
      boards = bs
      resolve()

proc deleteBoard(id: Id) =
  apiDeleteBoard id, proc =
    discard fetchBoards()


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
    notes.deleteIt it.id == id
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

        tdiv(class = "btn mx-1 btn-compact btn-outline-primary"):
          icon "fa-copy"
          proc onclick =
            copyToClipboard $n.id

        a(class = "btn mx-1 btn-compact btn-outline-dark",
            href = get_note_editor_url(n.id)):
          icon "fa-link"

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
        h3:
          text b.title

        span:
          text "time:"
          # text $b.timestamp

      tdiv(class = "card-footer d-flex justify-content-center"):
        a(class = "btn mx-1 btn-compact btn-outline-warning",
            href = get_board_editor_url b.id):
          icon "fa-pen"

        a(class = "btn mx-1 btn-compact btn-outline-danger"):
          icon "fa-close"

          proc onclick(e: Event, v: Vnode) =
            deleteBoard b.id
            redirect ""

proc genAddTagToList(id: Id): proc() =
  proc =
    currentRelTags.add id, c""

proc genActiveTagClick(tagId: Id, index: int): proc() =
  proc =
    activeRelTag = some (tagid, index)

# TODO search tag component

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
          apiUpdateNoteTags selectedNoteId, d, proc =
            notify "changes applied"
            notes[selectedNoteIndex].activeRelsValues = cast[RelValuesByTagId](d)

      button(class = "btn btn-warning w-100 mt-2 mb-4"):
        text "cancel"
        icon "mx-2 fa-hand"

        proc onclick =
          reset activeRelTag
          appState = asNormal

proc genRoundOperator(i: int, vt: TagValueType): proc() =
  proc =
    searchCriterias[i].operator.inc


proc genAddSearchCriteria(t: Tag): proc() =
  proc =
    searchCriterias.add TagCriteria(
      tagid: t.id,
      label: t.label,
      valuetype: t.valuetype,
      operator: qoExists,
      value: "")

    selectedCriteriaI = searchCriterias.high

proc genSelectCriteria(i: int): proc() = 
  proc = 
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

        searchTagManager()

        tdiv(class = "my-1"):
          button(class = "btn btn-outline-info w-100 mt-2 mb-4"):
            text "search"
            icon "mx-2 fa-search"

            proc onclick =
              case selectedClass
              of scUsers: discard
              of scNotes: discard fetchNotes()
              of scBoards: discard fetchBoards()
              of scAssets: discard


        tdiv(class = "my-4 masonry-container masonry-" & $columnsCount):
          case selectedClass
          of scUsers:
            text "not impl"

          of scNotes:
            for i, n in notes:
              notePreviewC n, i

          of scBoards:
            for b in boards:
              boardItemViewC b

          of scAssets:
            text "not impl"

      of asTagManager:
        relTagManager()


when isMainModule:
  setRenderer createDom

  waitAll [fetchTags(), fetchNotes(), fetchBoards()], proc =
    redraw()
