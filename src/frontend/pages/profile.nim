import std/[dom, options, random, asyncjs]

import karax/[karax, karaxdsl, vdom]
import questionable

import ../components/[snackbar, simple, pro]
import ../utils/[browser, api, js]
import ../../common/[conventions, datastructures, types]
import ../../backend/database/[models, logic]


type
  AppAction = enum
    aaBaleBot = "bale"
    aaLoginForm = "form"

  AppState = enum
    asInit
    asSelectIcon

const
  ttt = staticRead "./icons.txt"

let
  icons = splitlines ttt
  defaultIcon = icons[0]

var
  username: string
  pass: string
  state = aaBaleBot
  user: options.Option[User]

  tagState = asInit
  selectedTagI = noIndex
  currentTag = none Tag
  tags: seq[Tag]
  colors: seq[ColorTheme]


proc genSetState(i: AppAction): proc() =
  proc =
    state = i

func iconname(aa: AppAction): string =
  case aa
  of aaBaleBot: "fa-robot"
  of aaLoginForm: "fa-pen"


proc dummyTag: Tag =
  Tag(
    icon: defaultIcon,
    theme: sample colors,
    show_name: true,
    is_private: false,
    value_type: rvtNone,
    label: "name")

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

proc fetchAll =
  waitAll [fetchDefaultPalette(), fetchTags()], proc =
    redraw()

proc onIconSelected(icon: string) =
  currentTag.get.icon = icon
  tagState = asInit

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
          icon("fa-user fa-xl me-3 ms-1")
          text "Profile"

    if isNone user:
      ul(class = "pagination pagination-lg d-flex justify-content-center mt-2"):
        for i in AppAction:
          li(class = "page-item " & iff(i == state, "active")):
            a(class = "page-link", href = "#", onclick = genSetState i):
              span(class = "me-2"):
                text $i

              icon iconname i

    tdiv(class = "card border-secondary m-3 d-flex justify-content-center"):
      if u =? user:
        tdiv(class = "card-header"):
          text u.nickname

        button(class = "btn btn-danger w-100 mt-2 mb-4"):
          text "logout"
          icon "mx-2 fa-sign-out"

          proc onclick =
            logoutApi proc =
              notify "logged out"
              reset user
              redraw()

      else:
        tdiv(class = "card-header"):
          text "Login/signup Form"

        tdiv(class = "card-body p-2"):
          tdiv(class = "form-group"):
            case state
            of aaBaleBot: discard
            of aaLoginForm:
              label(class = "form-check-label"):
                text "username: "

              input(`type` = "text", class = "form-control",
                  value = username):
                proc oninput(e: Event, v: Vnode) =
                  username = $e.target.value

            label(class = "form-check-label"):
              text "pass: "

            input(`type` = "password", class = "form-control", value = pass):
              proc oninput(e: Event, v: Vnode) =
                pass = $e.target.value

            button(class = "btn btn-success w-100 mt-2 mb-4"):
              text "login"
              icon "mx-2 fa-sign-in"

              proc onclick =
                proc success =
                  notify "logged in :)"

                  meApi proc(u: User) =
                    user = some u
                    redraw()

                proc fail =
                  notify "pass wrong :("

                case state
                of aaBaleBot:
                  loginApi pass, success, fail
                of aaLoginForm:
                  loginApi username, pass, success, fail

    if (isSome currentTag) and (isSome user):
      tdiv(class = "p-4 mx-4 my-2"):
        h6(class = "mb-3"):
          icon "fa-bars-staggered me-2"
          text "All Tags"

        tdiv(class = "d-flex flex-row flex-wrap"):
          for i, t in tags:
            tagViewC t, "...", genChangeSelectedTagi i

      tdiv(class = "p-4 mx-4 my-2"):
        h6(class = "mb-3"):
          icon "fa-gear me-2"
          text "Config"

        tdiv(class = "form-control"):
          if tagState == asSelectIcon:
            tdiv(class = "d-flex flex-row flex-wrap justify-content-between"):
              for c in icons:
                iconSelectionBLock($c, onIconSelected)

          else:
            # name
            tdiv(class = "form-group d-inline-block mx-2"):
              label(class = "form-check-label"):
                text "name: "

              input(`type` = "text", class = "form-control tag-input",
                  value = currentTag.get.label):
                proc oninput(e: Event, v: Vnode) =
                  currentTag.get.label = e.target.value

            # icon
            tdiv(class = "form-check"):
              label(class = "form-check-label"):
                text "icon: "

              tdiv(class = "d-inline-block"):
                tdiv(class = "btn btn-lg btn-outline-dark rounded-2 m-2 p-2"):
                  icon "m-2 " & $currentTag.get.icon

                proc onclick =
                  tagState = asSelectIcon

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
                  if b: rvtStr
                  else: rvtNone

              label(class = "form-check-label"):
                text "has value"

            # value type
            tdiv(class = "form-group my-2"):
              label(class = "form-label"):
                text "value type"

              select(class = "form-select",
                  disabled = not currentTag.get.hasValue):
                for lbl in rvtStr..rvtDate:
                  option(value = cstr lbl.ord,
                      selected = currentTag.get.value_type == lbl):
                    text $lbl

                proc onInput(e: Event, v: Vnode) =
                  currentTag.get.value_type = RelValueType parseInt e.target.value

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
            tagViewC get currentTag, "...", noop

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
  fetchAll()

  meApi proc(u: User) =
    user = some u
    redraw()

when isMainModule:
  init()
