import std/[options, sequtils, tables]
import std/[dom, jsconsole, jsffi, asyncjs]

import karax/[karax, karaxdsl, vdom, vstyles]
import questionable

import ../components/[snackbar]
import ../utils/[browser, js, ui, api]
import ../../common/[iter, types, conventions]
import ../../backend/routes
import ../../backend/database/[models]
import ./editor/[core, components]


type
  AppState = enum
    asNormal
    asTagManager

  RelTagPath = tuple[tagid: Id, index: int]


let compTable = defaultComponents()
var
  appState = asNormal
  notes: seq[Note]
  msgCache: Table[Id, cstring]
  tags: Table[Id, Tag]
  columnsCount = 3
  currentRelTags: RelValuesByTagId = initNTable[cstring, seq[cstring]]()
  selectedNoteId: Id
  activeRelTag = none RelTagPath

# TODO write a note laod manager component in a different file
proc loadMsg(n: Note) =
  deserizalize(compTable, n.data).dthen proc(t: TwNode) =
    msgCache[n.id] = t.dom.innerHtml
    redraw()

proc fetchNotes: Future[void] =
  newPromise proc(resolve, reject: proc()) =
    apiGetNotesList proc(ns: seq[Note]) =
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

proc reqNewNote =
  apiCreateNewNote proc(id: Id) =
    redirect get_note_editor_url id

# ----- UI

proc columnCountSetter(i: int): proc() =
  proc =
    columnsCount = i


proc notePreviewC(n: Note): VNode =
  buildHtml:
    tdiv(class = "masonry-item card my-3 border rounded bg-white"):
      tdiv(class = "card-body"):
        if n.id in msgCache:
          verbatim msgCache[n.id]
        else:
          text "loading..."

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
            appState = asTagManager

        a(class = "btn mx-1 btn-compact btn-outline-warning",
            href = get_note_editor_url(n.id)):
          icon "fa-pen"

        button(class = "btn mx-1 btn-compact btn-outline-danger"):
          icon "fa-close"

          proc onclick =
            deleteNote n.id

proc genAddTagToList(id: Id): proc() =
  let key = cstr int id
  proc =
    # FIXME var getter for [] is not defined
    # if key in currentRelTags:
    #   currentRelTags[key].add Str c""
    # else:
      currentRelTags[key] = @[c""]

proc genActiveTagClick(tagId: Id, index: int): proc() =
  proc =
    activeRelTag = some (tagid, index)


# TODO make it globally available
proc relTagManager(rtvs: RelValuesByTagId): Vnode =
  buildHTML:
    tdiv:
      h3(class = "mt-4"):
        text "Available Tags"

      tdiv(class = "card"):
        tdiv(class = "card-body"):
          for id, t in tags:
            if (cstr int id) notin rtvs or t.can_be_repeated:
              tagViewC t, "val", genAddTagToList id

      h3(class = "mt-4"):
        text "Current Tags"

      tdiv(class = "card"):
        tdiv(class = "card-body"):
          for key, vals in rtvs:
            for index, v in vals:
              let id = Id parseInt key
              tagViewC tags[id], v, genActiveTagClick(id, index)

      if path =? activeRelTag:
        let t = tags[path.tagid]
        if t.hasValue:
          input(`type` = "text", class = "form-control", value = rtvs[
              cstr int path.tagid][path.index]):
            proc oninput(e: Event, v: Vnode) =
              let k = cstr int path.tagid
              # currentRelTags.sett k, path.index, cstring $e.target.value

        button(class = "btn btn-danger w-100 mt-2 mb-4"):
          text "remove"
          icon "mx-2 fa-close"

          proc onclick =
            let k = cstr int path.tagid
            delete currentRelTags[k], path.index


      button(class = "btn btn-primary w-100 mt-2"):
        text "save"
        icon "mx-2 fa-save"

        proc onclick =
          apiUpdateNoteTags selectedNoteId, currentRelTags, proc =
            discard fetchTags()
            notify "changes applied"

      button(class = "btn btn-warning w-100 mt-2 mb-4"):
        text "cancel"
        icon "mx-2 fa-hand"

        proc onclick =
          reset activeRelTag
          appState = asNormal


proc createDom: Vnode =
  echo "just redrawn"

  result = buildHtml tdiv:
    nav(class = "navbar navbar-expand-lg bg-white"):
      tdiv(class = "container-fluid"):
        a(class = "navbar-brand", href = "#"):
          icon "fa-note-sticky fa-xl me-3 ms-1"
          text "Notes"

    tdiv(class = "px-4 py-2 my-2"):
      case appState
      of asNormal:
        tdiv(class = "masonry-container justify-content-around my-4 masonry-" &
            $columnsCount):

          button(
            class = "masonry-item my-3 btn btn-outline-primary rounded",
            onclick = reqNewNote):
            icon "fa-plus fa-xl my-4"

          tdiv(class = "d-flex justify-content-center"):
            ul(class = "pagination pagination-lg"):
              for i in 1..4:
                li(class = "page-item " & iff(i == columnsCount, "active"),
                    onclick = columnCountSetter i):
                  a(class = "page-link", href = "#"):
                    text $i

          for n in notes:
            notePreviewC n

      of asTagManager:
        relTagManager currentRelTags

when isMainModule:
  setRenderer createDom

  waitAll [fetchTags(), fetchNotes()], proc =
    redraw()
