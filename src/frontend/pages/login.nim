import std/[dom, options]

import karax/[karax, karaxdsl, vdom]
import questionable

import ../components/[snackbar]
import ../utils/[ui, api]
import ../../common/[conventions]
import ../../backend/database/models


var 
  pass: string
  user: Option[User]

proc createDom: Vnode =
  result = buildHtml tdiv:
    snackbar()

    nav(class = "navbar navbar-expand-lg bg-white"):
      tdiv(class = "container-fluid"):
        a(class = "navbar-brand", href = "#"):
          icon("fa-user fa-xl me-3 ms-1")
          text "Login"

    tdiv(class = "card border-secondary mb-3"):
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
            text "Login Form"

          tdiv(class = "card-body p-2"):
            tdiv(class = "form-group d-inline-block"):
              label(class = "form-check-label"):
                text "pass: "

              input(`type` = "text", class = "form-control tag-input",
                  value = pass):
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

                  loginApi pass, success, fail

        


proc init* =
  setRenderer createDom
  meApi proc(u: User) = 
    user = some u
    redraw()

when isMainModule: init()
