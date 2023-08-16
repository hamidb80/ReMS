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

proc notePreviewC(np: NotePreview): VNode =
  buildHtml:
    tdiv(class="p-4 border rounded m-4 bg-white"):
      a(href = get_note_editor_url(np.id)):
        span:
          text "#"
          text $np.id

      verbatim deserizalize(compTable, np.preview).innerHtml


proc createDom: Vnode =
  echo "just redrawn"

  result = buildHtml tdiv:
    nav(class = "navbar navbar-expand-lg bg-white"):
      tdiv(class = "container-fluid"):
        a(class = "navbar-brand", href = "#"):
          icon("fa-paper fa-xl me-3 ms-1")
          text "Notes"

    tdiv(class = "p-4 m-4"):
      tdiv(class = "d-flex flex-wrap justify-content-around my-4"):
        button(class = "p-4 border rounded m-4 bg-white text-primary", onclick=reqNewNote):
          icon "fa-plus fa-xl"

        for n in notes:
          notePreviewC n

when isMainModule:
  setRenderer createDom
  fetchNotes()
