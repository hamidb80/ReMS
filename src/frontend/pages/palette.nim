import std/[dom, jsconsole, jsffi, asyncjs]

import karax/[karax, karaxdsl, vdom, vstyles]

import ../components/[snackbar]
import ../../backend/database/models
import ../../common/[conventions, datastructures, types]
import ../utils/[browser, ui, api, js]


var
  palettes: seq[Palette]
  selectedPaletteI: int = 0

proc genChangePalette(i: int): proc() =
  proc =
    selectedPaletteI = i

proc genColorBgInput(i: int): proc (e: Event, v: Vnode) =
  proc(e: Event, v: Vnode) =
    palettes[selectedPaletteI].colorThemes[
        i].bg = parseHexColorPack $e.target.value

proc genColorFgInput(i: int): proc (e: Event, v: Vnode) =
  proc(e: Event, v: Vnode) =
    palettes[selectedPaletteI].colorThemes[
        i].fg = parseHexColorPack $e.target.value

proc genColorStInput(i: int): proc (e: Event, v: Vnode) =
  proc(e: Event, v: Vnode) =
    palettes[selectedPaletteI].colorThemes[
        i].st = parseHexColorPack $e.target.value


# TODO delete btn
# TODO add between

proc createDom: Vnode =
  result = buildHtml tdiv:
    snackbar()

    nav(class = "navbar navbar-expand-lg bg-white"):
      tdiv(class = "container-fluid"):
        a(class = "navbar-brand", href = "#"):
          icon "fa-hashtag fa-xl me-3 ms-1"
          text "Palette"

    if palettes.len > 0:
      tdiv(class = "p-4 mx-4 my-2"):
        h6(class = "mb-3"):
          icon "fa-bars-staggered me-2"
          text "All Tags"


        ul(class = "pagination pagination-lg"):
          for i, p in palettes:
            li(class = "page-item " & iff(i == selectedPaletteI, "active"),
                onclick = genChangePalette i):
              a(class = "page-link", href = "#"):
                text p.name


        for i, c in palettes[selectedPaletteI].colorThemes:
          tdiv:
            # background
            tdiv(class = "form-group d-inline-block mx-2"):
              label(class = "form-check-label"):
                text "background color: "

              input(`type` = "color",
                  class = "form-control",
                  value = toColorString c.bg,
                  oninput = genColorBgInput i)

            # foreground
            tdiv(class = "form-group d-inline-block mx-2"):
              label(class = "form-check-label"):
                text "foreground color: "

              input(`type` = "color",
                  class = "form-control",
                  value = toColorString c.fg,
                  oninput = genColorFgInput i)

            # stroke
            tdiv(class = "form-group d-inline-block mx-2"):
              label(class = "form-check-label"):
                text "stroke color: "

              input(`type` = "color",
                  class = "form-control",
                  value = toColorString c.st,
                  oninput = genColorStInput i)

            # demo
            tdiv(class = "btn", style = style(
              (StyleAttr.background, toColorString c.bg),
              (StyleAttr.color, toColorString c.fg),
              (StyleAttr.borderColor, toColorString c.st),
              )):

                text "demo text"

      button(class = "btn btn-success w-100 mt-2 mb-4"):
        text "add"
        icon "mx-2 fa-plus"

        proc onclick =
          discard

      button(class = "btn btn-primary w-100 mt-2 mb-4"):
        text "update"
        icon "mx-2 fa-sync"

        proc onclick =
          let p = palettes[selectedPaletteI]
          apiUpdatePalette p, proc =
            notify "updated"


proc init* =
  setRenderer createDom

  apiListPalettes proc(ps: seq[Palette]) =
    palettes = ps
    redraw()

when isMainModule: init()
