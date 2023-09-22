import std/[options, sequtils, tables]
import std/[dom, jsconsole, jsffi, asyncjs]

import karax/[karax, karaxdsl, vdom, vstyles]

import ../utils/[browser, js, ui, api]
import ../../common/[iter, types, conventions]
import ../../backend/routes
import ../../backend/database/[models]
import ./editor/[core, components]


let compTable = defaultComponents()
var
  notes: seq[Note]
  msgCache: Table[Id, cstring]
  tags: Table[Id, Tag]
  columnsCount = 3


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
            discard

        a(class = "btn mx-1 btn-compact btn-outline-warning",
            href = get_note_editor_url(n.id)):
          icon "fa-pen"

        button(class = "btn mx-1 btn-compact btn-outline-danger"):
          icon "fa-close"

          proc onclick = 
            deleteNote n.id

# TODO
proc tagManager(s: seq[Tag]): Vnode = 
  discard


proc createDom: Vnode =
  echo "just redrawn"

  result = buildHtml tdiv:
    if true:
      nav(class = "navbar navbar-expand-lg bg-white"):
        tdiv(class = "container-fluid"):
          a(class = "navbar-brand", href = "#"):
            icon "fa-note-sticky fa-xl me-3 ms-1"
            text "Notes"

      tdiv(class = "px-4 py-2 my-2"):
        tdiv(class = "masonry-container justify-content-around my-4 masonry-" & $columnsCount):

          button(
            class = "masonry-item my-3 btn btn-outline-primary rounded",
            onclick = reqNewNote):
            icon "fa-plus fa-xl my-4"

          tdiv(class = "d-flex justify-content-center"):
            ul(class = "pagination pagination-lg"):
              for i in 1..4:
                li(class = "page-item " & iff(i == columnsCount, "active"), onclick = columnCountSetter i):
                  a(class="page-link", href="#"):
                    text $i

          for n in notes:
            notePreviewC n
    else:
      tdiv(class="w-100 h-100 bg-white"):
        text "HEY!!!!!!!!!!"
        # tagManager()

when isMainModule:
  setRenderer createDom
  
  waitAll [fetchTags(), fetchNotes()], proc =
    redraw()
