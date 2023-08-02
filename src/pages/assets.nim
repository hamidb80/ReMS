import std/[with, math, options, lenientops, strformat, random]
import std/[dom, jsconsole, jsffi, jsfetch, asyncjs, sugar]
import karax/[karax, karaxdsl, vdom, vstyles]
import caster

import ../[hotkeys, browser]


proc dropHandler(ev: Event) =
  console.log ev

  # if ev.dataTransfer.items:
  #   for i, item in ev.dataTransfer.items:
  #     # If dropped items aren't files, reject them
  #     if item.kind == "file":
  #       console.log item.getAsFile()
  # else:
  #   for i, file in ev.dataTransfer.files:
  #     console.log file

# TODO add "order by"
# TODO make tag searcher common in all modules [graph, assets, notes]

func progressbar(percent: float): Vnode =
  buildHtml:
    tdiv(class = "progress limited-progress"):
      tdiv(class = "progress-bar progress-bar-striped progress-bar-animated",
          style = style(StyleAttr.width, $percent & "%"))


type
  CmpOperator = enum
    lt   #  <
    lte  #  <=
    eq   #  ==
    neq  # !=
    gte  # >=
    gt   #  >
    like #  %

func tagSearch(name, color: string,
  # TODO inputType = int/string/...
  compareOperator: Option[CmpOperator]): VNode =

  buildHtml:
    tdiv(class = "form-group d-inline-block mx-2"):
      tdiv(class = "input-group mb-3"):
        span(class = "input-group-text"):
          italic(class = "fa-solid fa-hashtag me-2")
          span:
            text name

        if issome compareOperator:
          button(class = "input-group-text pointer btn btn-outline-primary"):
            let ic =
              case get compareOperator
              of lt: "fa-solid fa-less-than"
              of lte: "fa-solid fa-less-than-equal"
              of eq: "fa-solid fa-equals"
              of neq: "fa-solid fa-not-equal"
              of gte: "fa-solid fa-greater-than-equal"
              of gt: "fa-solid fa-greater-than"
              of like: "fa-solid fa-percent"

            italic(class = ic)

          input(class = "form-control tag-input", `type` = "text")

        tdiv(class = "input-group-text btn btn-outline-danger d-flex align-items-center justify-content-center p-2"):
          italic(class = "fa-solid fa-xmark")

proc createDom: Vnode =
  result = buildHtml tdiv:
    nav(class = "navbar navbar-expand-lg bg-white"):
      tdiv(class = "container-fluid"):
        a(class = "navbar-brand", href = "#"):
          italic(class = "fa-solid fa-box-open fa-xl me-3 ms-1")
          text "Assets"

    tdiv(class = "p-4 m-4"):
      h6(class = "mb-3"):
        italic(class = "fa-solid fa-arrow-pointer me-2")
        text "Select / Paste / Drag"

      tdiv(class = "rounded p-3 rounded bg-white d-flex flex-column align-items-center justify-content-center"):
        tdiv(class = "form-group w-100"):
          input(class = "form-control", `type` = "file",
              placeholder = "select a file"):
            proc oninput(e: Event, v: VNode) =
              discard

        tdiv(class = "my-3")

        tdiv(class = """dropper bg-light border-secondary grab
              border border-4 border-dashed rounded-2 user-select-none
              d-flex justify-content-center align-items-center"""):

          tdiv():
            text "drag file or copy something here"

          tdiv():
            text "when hover"


          proc ondrop(e: Event, v: VNode) =
            e.preventdefault
            dropHandler e

          proc ondragover(e: Event, v: VNode) =
            e.preventdefault

      h6(class = "mt-4 mb-3"):
        italic(class = "fa-solid fa-spinner fa-spin-pulse me-2")
        text "in progress uploads"

      tdiv(class = "list-group mb-4"):
        tdiv(class = "d-flex flex-row align-items-center justify-content-between list-group-item list-group-item-action"):
          text "Cras justo odio"
          progressbar 50.0
          # TODO add cancel button


        tdiv(class = "d-flex flex-row align-items-center justify-content-between list-group-item list-group-item-action"):
          text "Dapibus ac facilisis in"
          progressbar 50.0

        tdiv(class = "d-flex flex-row align-items-center justify-content-between list-group-item list-group-item-action disabled"):
          text "Morbi leo risus"
          progressbar 50.0

      tdiv(class = "form-group"):
        h6(class = "mb-3"):
          italic(class = "fa-solid fa-hashtag me-2")
          text "search by tags"

        tagSearch("id", "red", some neq)
        tagSearch("extention", "black", some lte)
        tagSearch("time", "gray", none CmpOperator)

        button(class = "btn btn-success w-100 my-2"):
          text "add tag"
          # TODO remove this, add all tags below
          italic(class = "fa-solid fa-plus ms-2")

        h6(class = "mb-3"):
          italic(class = "fa-solid fa-arrow-up-wide-short me-2")
          text "order results by"

      tdiv(class = "form-group"):
        button(class = "btn btn-primary w-100"):
          text "search"
          italic(class = "fa-solid fa-magnifying-glass ms-2")

      tdiv(class = ""):
        # switch list/block view
        for i in 0..10:
          discard # files uploaded


      tdiv(class = "form-group"):
        button(class = "btn btn-warning w-100 mt-3"):
          text "load more"
          italic(class = "fa-solid fa-angles-right ms-2")

when isMainModule:
  window.addEventListener "paste", proc(e: Event) =
    console.log e

  setRenderer createDom
