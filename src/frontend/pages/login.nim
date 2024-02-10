import std/[dom, options]

import karax/[karax, karaxdsl, vdom]
import questionable

import ../components/[snackbar]
import ../utils/[ui, api]
import ../../common/[conventions]
import ../../backend/database/models

# TODO merge tag manager and user manager and login & profile and pallete in one page

type AppAction = enum
  aaBaleBot = "bale"
  aaLoginForm = "form"

var
  username: string
  pass: string
  state = aaBaleBot
  user: Option[User]

proc genSetState(i: AppAction): proc() =
  proc =
    state = i

# TODO form to change username/nickname
# TODO see bale chat id
# TODO enable login by password
# TODO link to tag manager
# TODO link to palette manager

func iconname(aa: AppAction): string = 
  case aa
  of aaBaleBot: "fa-robot"
  of aaLoginForm: "fa-pen"

proc createDom: Vnode =
  result = buildHtml tdiv:
    snackbar()

    nav(class = "navbar navbar-expand-lg bg-white"):
      tdiv(class = "container-fluid"):
        a(class = "navbar-brand", href = "#"):
          icon("fa-user fa-xl me-3 ms-1")
          text "Login"


    ul(class = "pagination pagination-lg d-flex justify-content-center mt-2"):
      for i in AppAction:
        li(class = "page-item " & iff(i == state, "active")):
          a(class = "page-link", href = "#", onclick = genSetState i):
            span(class="me-2"):
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

              input(`type` = "text", class = "form-control", value = username):
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


proc init* =
  setRenderer createDom
  meApi proc(u: User) =
    user = some u
    redraw()

when isMainModule: init()
