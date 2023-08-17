import std/[options, lenientops, strformat, httpcore, sequtils, times]
import std/[dom, jsconsole, jsffi, asyncjs, jsformdata, sugar]
import karax/[karax, karaxdsl, vdom, vstyles]
import caster

import ../jslib/[hotkeys, axios]
import ../utils/[browser, js, ui]
import ../../common/[conventions, iter, types]
import ../../backend/routes
import ../../backend/database/[queries]
import ./editor/[core, components]


let compTable = defaultComponents()
var notes: seq[NotePreview]

proc fetchNotes =
  get_api_notes_list_url().getApi.dthen proc(r: AxiosResponse) =
    notes = cast[typeof notes](r.data)
    redraw()

proc reqNewNote =
  post_api_notes_new_url().postApi.dthen proc(r: AxiosResponse) =
    let id = cast[int64](r.data)
    redirect get_note_editor_url id


# ----- UI
# TODO make preview note a indepepndent component / used in board.nim too
proc notePreviewC(np: NotePreview): VNode =
  buildHtml:
    tdiv(class = "masonry-item card m-4 border rounded bg-white"):
      tdiv(class = "card-body"):
        verbatim deserizalize(compTable, np.preview).innerHtml
      tdiv(class = "card-footer d-flex justify-content-center"):
        a(class = "btn mx-1 btn-compact btn-outline-info",
            href = get_note_editor_url(np.id)):
          icon "fa-link"
        a(class = "btn mx-1 btn-compact btn-outline-warning",
            href = get_note_editor_url(np.id)):
          icon "fa-pen"
        button(class = "btn mx-1 btn-compact btn-outline-danger"):
          icon "fa-close"



proc createDom: Vnode =
  echo "just redrawn"

  result = buildHtml tdiv:
    nav(class = "navbar navbar-expand-lg bg-white"):
      tdiv(class = "container-fluid"):
        a(class = "navbar-brand", href = "#"):
          icon("fa-note-sticky fa-xl me-3 ms-1")
          text "Notes"

    tdiv(class = "p-4 m-4"):
      tdiv(class = "masonry-container justify-content-around my-4"):
        button(
          class = "masonry-item p-4 m-4 btn btn-outline-primary rounded",
          onclick = reqNewNote):
          icon "fa-plus fa-xl my-4"

        for n in notes:
          notePreviewC n

when isMainModule:
  setRenderer createDom
  fetchNotes()
