import std/[options, lenientops, strformat, httpcore, sequtils, times, tables]
import std/[dom, jsconsole, jsffi, asyncjs, jsformdata, sugar]

import karax/[karax, karaxdsl, vdom, vstyles]
import caster

import ../jslib/[hotkeys, axios]
import ../utils/[browser, js, ui]
import ../../common/[conventions, iter, types]
import ../../backend/routes
import ../../backend/database/[models]
import ./editor/[core, components]


let compTable = defaultComponents()
var
  notes: seq[Note]
  msgCache: Table[Id, cstring]

# TODO write a note laod manager component in a different file
proc getMsg(n: Note) = 
  deserizalize(compTable, n.data).dthen proc(t: TwNode) =
    msgCache[n.id] = t.dom.innerHtml
    redraw()

proc fetchNotes =
  get_api_notes_list_url().getApi.dthen proc(r: AxiosResponse) =
    notes = cast[typeof notes](r.data)
    for n in notes:
      getMsg n
      
proc deleteNote(id: Id) = 
  delete_api_note_url(id).deleteApi.dthen proc(r: AxiosResponse) = 
    notes.deleteIt it.id == id
    redraw()

proc reqNewNote =
  post_api_notes_new_url().postApi.dthen proc(r: AxiosResponse) =
    let id = cast[Id](r.data)
    redirect get_note_editor_url id

# ----- UI
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

        a(class = "btn mx-1 btn-compact btn-outline-warning",
            href = get_note_editor_url(n.id)):
          icon "fa-pen"

        button(class = "btn mx-1 btn-compact btn-outline-danger"):
          icon "fa-close"

          proc onclick = 
            deleteNote n.id

# TODO add ability to choose columns
proc createDom: Vnode =
  echo "just redrawn"

  result = buildHtml tdiv:
    nav(class = "navbar navbar-expand-lg bg-white"):
      tdiv(class = "container-fluid"):
        a(class = "navbar-brand", href = "#"):
          icon("fa-note-sticky fa-xl me-3 ms-1")
          text "Notes"

    tdiv(class = "px-4 py-2 my-2"):
      tdiv(class = "masonry-container justify-content-around my-4"):
        button(
          class = "masonry-item my-3 btn btn-outline-primary rounded",
          onclick = reqNewNote):
          icon "fa-plus fa-xl my-4"

        for n in notes:
          notePreviewC n

when isMainModule:
  setRenderer createDom
  fetchNotes()
