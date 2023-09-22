import std/[with, strutils, sequtils, options]
import std/[dom, jsconsole, jsffi]

import karax/[karax, karaxdsl, vdom, vstyles]
import caster

import ../components/[snackbar]
import ../../backend/database/models
import ../../common/[conventions, datastructures, types]
import ../utils/[browser, ui, api]


type
  AppState = enum
    asInit
    asSelectIcon

const
  icons = splitlines staticRead "./icons.txt"
  defaultIcon = icons[0]
  noIndex = -1


var
  state = asInit
  selectedTagI = noIndex
  currentTag: Tag
  tags: seq[Tag]
  colors: seq[ColorTheme]


proc dummyTag: Tag =
  Tag(
    icon: defaultIcon,
    theme: colors[1],
    name: "name")


proc fetchTags =
  apiGetTagsList proc (ts: seq[Tag]) =
    tags = ts
    redraw()

proc onIconSelected(icon: string) =
  currentTag.icon = icon
  state = asInit

proc genChangeSelectedTagi(i: int): proc() =
  proc =
    if selectedTagI == i:
      selectedTagI = noIndex
      currentTag = dummyTag()
    else:
      selectedTagI = i
      currentTag = tags[i]

proc tag(
  t: Tag,
  value: string,
  selected: bool,
  forceShowName: bool,
  clickHandler: proc()
): VNode =
  buildHtml:
    tdiv(class = """d-inline-flex align-items-center py-2 px-3 mx-2 my-1 
      badge border-1 solid-border rounded-pill pointer""",
      onclick = clickHandler,
      style = style(
      (StyleAttr.background, toColorString t.theme.bg),
      (StyleAttr.color, toColorString t.theme.fg),
      (StyleAttr.borderColor, toColorString t.theme.fg),
    )):
      icon $t.icon

      span(dir = "auto", class = "ms-2"):
        text t.name

        if t.hasValue:
          text ": "
          text value

proc checkbox(active: bool, changeHandler: proc(b: bool)): VNode =
  result = buildHtml:
    input(class = "form-check-input", `type` = "checkbox", checked = active):
      proc onInput(e: Event, v: Vnode) =
        changeHandler not e.target.checked

proc iconSelectionBLock(icon: string, setIcon: proc(icon: string)): VNode =
  buildHtml:
    tdiv(class = "btn btn-lg btn-outline-dark rounded-2 m-1 p-2"):
      icon " m-2 " & icon
      proc onclick =
        setIcon icon


proc createDom: Vnode =
  result = buildHtml tdiv:
    snackbar()
    
    nav(class = "navbar navbar-expand-lg bg-white"):
      tdiv(class = "container-fluid"):
        a(class = "navbar-brand", href = "#"):
          icon "fa-hashtag fa-xl me-3 ms-1"
          text "Tags"

    tdiv(class = "p-4 mx-4 my-2"):
      h6(class = "mb-3"):
        icon "fa-bars-staggered me-2"
        text "All Tags"

      tdiv(class = "d-flex flex-row"):
        for i, t in tags:
          tag(t, "val", t.icon == currentTag.icon, true,
              genChangeSelectedTagi i)

    tdiv(class = "p-4 mx-4 my-2"):
      h6(class = "mb-3"):
        icon "fa-gear me-2"
        text "Config"

      tdiv(class = "form-control"):
        if state == asSelectIcon:
          tdiv(class = "d-flex flex-row flex-wrap justify-content-between"):
            for c in icons:
              iconSelectionBLock(c, onIconSelected)

        else:
          # name
          tdiv(class = "form-group d-inline-block mx-2"):
            label(class = "form-check-label"):
              text "name: "

            input(`type` = "text", class = "form-control tag-input",
                value = currentTag.name):
              proc oninput(e: Event, v: Vnode) =
                currentTag.name = $e.target.value

          # icon
          tdiv(class = "form-check"):
            label(class = "form-check-label"):
              text "icon: "

            tdiv(class = "d-inline-block"):
              tdiv(class = "btn btn-lg btn-outline-dark rounded-2 m-2 p-2"):
                icon "m-2 " & $currentTag.icon

              proc onclick =
                state = asSelectIcon

          # has value
          # TODO select which type of value
          tdiv(class = "form-check form-switch"):
            let onChange = proc (b: bool) =
              currentTag.value_type =
                if b: tvtStr
                else: tvtNone

            checkbox currentTag.hasValue, onChange

            label(class = "form-check-label"):
              text "has value"

          # color theme
          # background
          tdiv(class = "form-group d-inline-block mx-2"):
            label(class = "form-check-label"):
              text "background color: "

            input(`type` = "color",
                class = "form-control",
                value = toColorString currentTag.theme.bg):
              proc oninput(e: Event, v: Vnode) =
                currentTag.theme.bg = parseHexColorPack $e.target.value

              # foreground
          tdiv(class = "form-group d-inline-block mx-2"):
            label(class = "form-check-label"):
              text "foreground color: "

            input(`type` = "color",
                class = "form-control",
                value = toColorString currentTag.theme.fg):
              proc oninput(e: Event, v: Vnode) =
                currentTag.theme.fg = parseHexColorPack $e.target.value

        tdiv(class="my-2"):
          tag(currentTag, "val", false, false, noop)

        if selectedTagI == noIndex:
          button(class = "btn btn-success w-100 mt-2 mb-4"):
            text "add"
            icon "mx-2 fa-plus"

            proc onclick =
              apiCreateNewTag currentTag, proc = 
                fetchTags()
                notify "tag created"

        else:
          button(class = "btn btn-primary w-100 mt-2"):
            text "update"
            icon "mx-2 fa-sync"

            proc onclick =
              apiUpdateTag currentTag, proc = 
                fetchTags()
                notify "tag updated"

          button(class = "btn btn-danger w-100 mt-2 mb-4"):
            text "delete"
            icon "mx-2 fa-trash"

            proc onclick =
              apiDeleteTag currentTag.id, proc = 
                fetchTags()
                notify "tag deleted"


proc init* =
  setRenderer createDom

  apiGetPallete "default", proc(cs: seq[ColorTheme]) =
    colors = cs
    currentTag.theme = cs[0]
    currentTag = dummyTag()
    fetchTags()

when isMainModule: init()
