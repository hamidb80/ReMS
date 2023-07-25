import std/[with, math, options, lenientops, strformat, random]
import std/[dom, jsconsole, jsffi, jsfetch, asyncjs, sugar]
import karax/[karax, karaxdsl, vdom, vstyles]
import caster

import hotkeys, browser


proc createDom: Vnode =
  result = buildHtml tdiv:
    nav(class = "navbar navbar-expand-lg bg-light"):
      tdiv(class = "container-fluid"):
        a(class = "navbar-brand", href = "#"):
          text "Navbar"

    tdiv(class = "p-4 m-4"):
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
  setRenderer createDom
