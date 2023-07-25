import std/[with, math, options, lenientops, strformat, random]
import std/[dom, jsconsole, jsffi, jsfetch, asyncjs, sugar]
import karax/[karax, karaxdsl, vdom, vstyles]
import caster

import hotkeys, browser


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

func progressbar(percent: float): Vnode =
  buildHtml:
    tdiv(class = "progress limited-progress"):
      tdiv(class = "progress-bar progress-bar-striped progress-bar-animated",
          style = style(StyleAttr.width, $percent & "%"))


proc createDom: Vnode =
  result = buildHtml tdiv:
    nav(class = "navbar navbar-expand-lg bg-light"):
      tdiv(class = "container-fluid"):
        a(class = "navbar-brand", href = "#"):
          text "Navbar"

    tdiv(class = "p-4 m-4"):
      tdiv(class = "rounded p-3 rounded bg-white d-flex flex-column align-items-center justify-content-center"):
        tdiv(class = "form-group w-100"):
          label(class = "form-label", `for` = "formFile"):
            text "Default file input example"
          input(class = "form-control", `type` = "file"):
            proc oninput(e: Event, v: VNode) =
              discard

        tdiv(class = """dropper mt-4 bg-light border-secondary grab
              border border-4 border-dashed rounded-2 
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


      tdiv(class = "list-group my-4"):
        tdiv(class = "d-flex flex-row align-items-center justify-content-between list-group-item list-group-item-action"):
          text "Cras justo odio"
          progressbar 50.0

        tdiv(class = "d-flex flex-row align-items-center justify-content-between list-group-item list-group-item-action"):
          text "Dapibus ac facilisis in"
          progressbar 50.0

        tdiv(class = "d-flex flex-row align-items-center justify-content-between list-group-item list-group-item-action disabled"):
          text "Morbi leo risus"
          progressbar 50.0


      tdiv(class = "form-group"):
        input(`type` = "text", class = "form-control",
            placeholder = "by name")

        button(class = "btn btn-primary"):
          text "search"
          italic(class = "fa-solid fa-magnifying-glass ms-2")


when isMainModule:
  window.addEventListener "paste", proc(e: Event) =
    console.log e

  setRenderer createDom
