import std/[with, strutils, sequtils, options, random]
import std/[dom, jsconsole, jsffi, asyncjs]

import karax/[karax, karaxdsl, vdom, vstyles]
import caster

import ../components/[snackbar]
import ../../backend/database/models
import ../../common/[conventions, datastructures, types]
import ../utils/[browser, ui, api, js]


randomize()


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
  currentTag = none Tag
  tags: seq[Tag]
  colors: seq[ColorTheme]


# TODO show name of the icon on the bottom of it

proc dummyTag: Tag =
  Tag(
    icon: defaultIcon,
    theme: sample colors,
    show_name: true,
    is_private: false,
    value_type: tvtNone,
    name: "name")

proc fetchDefaultPalette: Future[void] =
  newPromise proc(resolve, reject: proc()) =
    apiGetPalette "default", proc(cs: seq[ColorTheme]) =
      colors = cs
      currentTag = some dummyTag()
      resolve()

proc fetchTags: Future[void] =
  newPromise proc(resolve, reject: proc()) =
    apiGetTagsList proc (ts: seq[Tag]) =
      tags = ts
      resolve()

proc onIconSelected(icon: string) =
  currentTag.get.icon = icon
  state = asInit

proc genChangeSelectedTagi(i: int): proc() =
  proc =
    if selectedTagI == i:
      selectedTagI = noIndex
      currentTag = some dummyTag()
    else:
      selectedTagI = i
      currentTag = some tags[i]


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

    if issome currentTag:
      tdiv(class = "p-4 mx-4 my-2"):
        h6(class = "mb-3"):
          icon "fa-bars-staggered me-2"
          text "All Tags"

        tdiv(class = "d-flex flex-row flex-wrap"):
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
                  value = currentTag.get.name):
                proc oninput(e: Event, v: Vnode) =
                  currentTag.get.name = $e.target.value

            # icon
            tdiv(class = "form-check"):
              label(class = "form-check-label"):
                text "icon: "

              tdiv(class = "d-inline-block"):
                tdiv(class = "btn btn-lg btn-outline-dark rounded-2 m-2 p-2"):
                  icon "m-2 " & $currentTag.get.icon

                proc onclick =
                  state = asSelectIcon

            tdiv(class = "form-check form-switch"):
              checkbox currentTag.get.is_private, proc (b: bool) =
                currentTag.get.is_private = b

              label(class = "form-check-label"):
                text "is private"

            tdiv(class = "form-check form-switch"):
              checkbox currentTag.get.show_name, proc (b: bool) =
                currentTag.get.show_name = b

              label(class = "form-check-label"):
                text "show name"

            # has value
            tdiv(class = "form-check form-switch"):
              checkbox currentTag.get.hasValue, proc (b: bool) =
                currentTag.get.value_type =
                  if b: tvtStr
                  else: tvtNone

              label(class = "form-check-label"):
                text "has value"

            # value type
            tdiv(class = "form-group my-2"):
              label(class = "form-label"):
                text "value type"

              select(class = "form-select", disabled = not currentTag.get.hasValue):
                for lbl in tvtStr..tvtJson:
                  option(value = cstr lbl.ord, selected = currentTag.get.value_type == lbl):
                    text $lbl

                proc onInput(e: Event, v: Vnode) =
                  currentTag.get.value_type = TagValueType parseInt e.target.value

            # background
            tdiv(class = "form-group d-inline-block mx-2"):
              label(class = "form-check-label"):
                text "background color: "

              input(`type` = "color",
                  class = "form-control",
                  value = toColorString currentTag.get.theme.bg):
                proc oninput(e: Event, v: Vnode) =
                  currentTag.get.theme.bg = parseHexColorPack $e.target.value

            # foreground
            tdiv(class = "form-group d-inline-block mx-2"):
              label(class = "form-check-label"):
                text "foreground color: "

              input(`type` = "color",
                  class = "form-control",
                  value = toColorString currentTag.get.theme.fg):
                proc oninput(e: Event, v: Vnode) =
                  currentTag.get.theme.fg = parseHexColorPack $e.target.value

          tdiv(class = "my-2"):
            tagViewC get currentTag, "val", noop

          if selectedTagI == noIndex:
            button(class = "btn btn-success w-100 mt-2 mb-4"):
              text "add"
              icon "mx-2 fa-plus"

              proc onclick =
                apiCreateNewTag currentTag.get, proc =
                  notify "tag created"
                  waitAll [fetchTags()], proc = redraw()

          else:
            button(class = "btn btn-primary w-100 mt-2"):
              text "update"
              icon "mx-2 fa-sync"

              proc onclick =
                apiUpdateTag get currentTag, proc =
                  notify "tag updated"
                  waitAll [fetchTags()], proc = redraw()

            button(class = "btn btn-danger w-100 mt-2 mb-4"):
              text "delete"
              icon "mx-2 fa-trash"

              proc onclick =
                apiDeleteTag currentTag.get.id, proc =
                  notify "tag deleted"
                  waitAll [fetchTags()], proc = redraw()

proc init* =
  setRenderer createDom

  waitAll [fetchDefaultPalette(), fetchTags()], proc =
    redraw()


when isMainModule: init()
