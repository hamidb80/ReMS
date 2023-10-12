import std/[options, sequtils, tables]
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


type
  RelTagPath = tuple[tagid: Id, index: int]

var
  compTable = defaultComponents()
  tags: Table[Id, Tag]
  note: NoteItemView
  html = c""

proc fetchNote(id: Id): Future[void] =
  newPromise proc(resolve, reject: proc()) =
    apiGetNote id, proc(n: NoteItemView) =
      deserizalize(compTable, n.data)
      .dthen proc(t: TwNode) =
        note = n
        html = t.dom.innerHtml
        redraw()

proc fetchTags(): Future[void] =
  newPromise proc(resolve, reject: proc()) =
    apiGetTagsList proc(tagsList: seq[Tag]) =
      for t in tagsList:
        tags[t.id] = t
      resolve()

# ----- UI

proc notePreviewC(n: NoteItemView): VNode =
  buildHtml:
    tdiv(class = "card my-3 masonry-item border rounded bg-white"):
      tdiv(class = "card-body"):
        tdiv(class = "tw-content"):
          if html != "":
            verbatim html
          else:
            text "loading..."

      tdiv(class = "m-2"):
        for k, values in n.activeRelsValues:
          for v in values:
            let id = Id parseInt k
            tagViewC tags[id], v, noop

proc createDom: Vnode =
  echo "just redrawn"

  result = buildHtml tdiv:
    snackbar()

    nav(class = "navbar navbar-expand-lg bg-white"):
      tdiv(class = "container-fluid"):
        a(class = "navbar-brand", href = "#"):
          icon "fa-search fa-xl me-3 ms-1"
          text "Explore"

    tdiv(class = "note-preview d-flex justify-content-center"):
      notePreviewC note


when isMainModule:
  setRenderer createDom
  let id = parseInt getWindowQueryParam "id"
  waitAll [fetchTags(), fetchNote id], proc =
    redraw()