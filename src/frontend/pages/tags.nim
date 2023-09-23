import std/[with, strutils, sequtils, options, random]
import std/[dom, jsconsole, jsffi]

import karax/[karax, karaxdsl, vdom, vstyles]
import caster

import ../components/[snackbar]
import ../../backend/database/models
import ../../common/[conventions, datastructures, types]
import ../utils/[browser, ui, api, js]


type
  AppState = enum
    asInit
    asSelectIcon

const
  icons = splitlines staticRead "./icons.txt"
  defaultIcon = icons[0]

var
  state = asInit
  selectedTagI = noIndex
  currentTag: Tag
  tags: seq[Tag]
  colors: seq[ColorTheme]


proc dummyTag: Tag =
  Tag(
    icon: defaultIcon,
    theme: sample colors,
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
          tagViewC t, "val", genChangeSelectedTagi i

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

          # TODO add show name

          # has value
          tdiv(class = "form-check form-switch"):
            let onChange = proc (b: bool) =
              currentTag.value_type =
                if b: tvtStr
                else: tvtNone

            checkbox currentTag.hasValue, onChange

            label(class = "form-check-label"):
              text "has value"

          # value type
          if currentTag.hasValue:
            tdiv(class = "form-group my-2"):
              label(class = "form-label"):
                text "value type"
              
              select(class = "form-select"):
                for lbl in tvtStr..tvtJson:
                  option(value = cstr lbl.ord, selected = currentTag.value_type == lbl):
                    text $lbl

                proc onInput(e: Event, v: Vnode) = 
                  currentTag.value_type = TagValueType parseInt e.target.value

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
          tagViewC currentTag, "val", noop

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
