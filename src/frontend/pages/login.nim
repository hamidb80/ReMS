import std/[dom]

import karax/[karax, karaxdsl, vdom]

import ../components/[snackbar]
import ../utils/[ui, api]
import ../../common/[conventions]
import ../../backend/database/models


type
  AppState = enum
    asAdmin = "admin"
    asUser = "user"

var 
  state = asUser
  pass: string

proc stateSetter(i: AppState): proc() = 
  proc = 
    state = i

proc createDom: Vnode =
  result = buildHtml tdiv:
    snackbar()

    nav(class = "navbar navbar-expand-lg bg-white"):
      tdiv(class = "container-fluid"):
        a(class = "navbar-brand", href = "#"):
          icon("fa-user fa-xl me-3 ms-1")
          text "Login"

    ## 
    ul(class = "pagination pagination-lg"):
      for i in AppState:
        li(class = "page-item " & iff(i == state, "active"),
            onclick = stateSetter i):
          a(class = "page-link", href = "#"):
            text $i

    tdiv(class = "card border-secondary mb-3"):
      tdiv(class = "card-header"):
        text "Login Form"
      tdiv(class = "card-body p-2"):
        
        case state
        of asAdmin:
          tdiv(class = "form-group d-inline-block"):
            label(class = "form-check-label"):
              text "pass: "

            input(`type` = "password", class = "form-control tag-input",
                value = pass):
              proc oninput(e: Event, v: Vnode) =
                pass = $e.target.value

            button(class = "btn btn-success w-100 mt-2 mb-4"):
              text "login"
              icon "mx-2 fa-sign-in"

              proc onclick =
                proc success =
                  notify "logged in :)"

                proc fail =
                  notify "pass wrong :("

                loginApi pass, success, fail

            button(class = "btn btn-danger w-100 mt-2 mb-4"):
              text "logout"
              icon "mx-2 fa-sign-out"

              proc onclick =
                logoutApi proc =
                  notify "logged out"

        of asUser:
          text "Wow"

proc init* =
  setRenderer createDom

when isMainModule: init()
