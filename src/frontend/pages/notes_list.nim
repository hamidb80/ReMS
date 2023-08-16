import std/[options, lenientops, strformat, httpcore, sequtils, times]
import std/[dom, jsconsole, jsffi, asyncjs, jsformdata, sugar]
import karax/[karax, karaxdsl, vdom, vstyles]
import caster

import ../jslib/[hotkeys, axios]
import ../utils/[browser, js, ui]
import ../../common/[conventions, iter, types]
import ../../backend/routes
import ../../backend/database/[queries]


var 
  notes: seq[NotePreview]

proc fetchNotes =
  get_api_notes_list_url().postApi.dthen proc(r: AxiosResponse) =
    notes = cast[typeof notes](r.data)
    redraw()

proc reqNewNote = 
  post_api_notes_new_url().postApi.dthen proc(r: AxiosResponse) =
    let id = cast[int64](r.data)
    redirect get_note_editor_url id


# ----- UI

func notePreviewC(np: NotePreview): VNode =
  buildHtml:
    a(class = "p-4 border rounded m-4 bg-white", href = get_note_editor_url(np.id)):
      # verbatim deserialize(app, np.previewp).innerHtml
      verbatim np.preview.stringify

proc createDom: Vnode =
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
