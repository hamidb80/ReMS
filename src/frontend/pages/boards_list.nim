import std/[options, lenientops, strformat, httpcore, sequtils, times]
import std/[dom, jsconsole, asyncjs, jsformdata, sugar]
import karax/[karax, karaxdsl, vdom]
import caster

import ../jslib/[axios]
import ../utils/[browser, js, ui]
import ../../common/[conventions, iter, types]
import ../../backend/routes
import ../../backend/database/[models, queries]


var boards: seq[BoardPreview]

proc fetchBoards =
  get_api_boards_list_url().getApi.dthen proc(r: AxiosResponse) =
    boards = cast[typeof boards](r.data)
    console.log boards
    redraw()

proc reqNewBoard =
  post_api_boards_new_url().postApi.dthen proc(r: AxiosResponse) =
    let id = cast[Id](r.data)
    redirect get_board_url id

# ----- UI
proc boardPreviewC(b: BoardPreview): VNode =
  buildHtml:
    tdiv(class = "masonry-item card my-3 border rounded bg-white"):
      tdiv(class = "d-flex bg-light card-img justify-content-center overflow-hidden"):
        img(src = get_asset_short_hand_url(b.screenshot))

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

        button(class = "btn mx-1 btn-compact btn-outline-danger"):
          icon "fa-close"



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
