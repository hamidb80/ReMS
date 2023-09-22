import std/[options, lenientops, strformat, httpcore, sequtils, times]
import std/[dom, jsconsole, asyncjs, jsformdata, sugar]
import karax/[karax, karaxdsl, vdom]
import caster, questionable

import ../utils/[browser, js, ui, api]
import ../../common/[conventions, iter, types]
import ../../backend/routes
import ../../backend/database/[models]


var boards: seq[BoardPreview]

proc fetchBoards =
  apiGetBoardsList proc(bs: seq[BoardPreview]) =
    boards = bs
    redraw()

proc reqNewBoard =
  apiCreateNewBoard proc(id: Id) =
    redirect get_board_url id

proc deleteBoard(id: Id) =
  apiDeleteBoard id, fetchBoards

# ----- UI

proc boardPreviewC(b: BoardPreview): VNode =
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
            href = get_board_url(b.id)):
          icon "fa-pen"

        a(class = "btn mx-1 btn-compact btn-outline-danger"):
          icon "fa-close"

          proc onclick(e: Event, v: Vnode) =
            deleteBoard b.id
            redirect ""

proc createDom: Vnode =
  echo "just redrawn"

  result = buildHtml tdiv:
    nav(class = "navbar navbar-expand-lg bg-white"):
      tdiv(class = "container-fluid"):
        a(class = "navbar-brand", href = "#"):
          icon("fa-note-sticky fa-xl me-3 ms-1")
          text "Boards"

    tdiv(class = "px-4 py-2 my-2"):
      tdiv(class = "masonry-container justify-content-around my-4"):
        button(
          class = "masonry-item my-3 btn btn-outline-primary rounded",
          onclick = reqNewBoard):
          icon "fa-plus fa-xl my-4"

        for b in boards:
          boardPreviewC b

when isMainModule:
  setRenderer createDom
  fetchBoards()
