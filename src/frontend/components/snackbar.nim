import std/dom
import karax/[karax, karaxdsl, vdom]
import ../utils/[js]


var
    notif = cstring ""
    timeout: TimeOut
    hidden = true

proc notify*(text: cstring, delay = 2000) {.exportc.} =
    notif = text
    hidden = false
    redraw()
    clearTimeout timeout
    timeout = setTimeout delay:
        proc =
            hidden = true
            redraw()

proc snackbar*: Vnode =
    let displayClass =
        if hidden: "opacity-0"
        else: "opacity-75"

    buildHtml:
        tdiv(class = "d-flex justify-content-center fixed-bottom mb-3 pe-none"):
            tdiv(class = "transition bg-black text-white px-2 py-1 rounded small " & displayClass):
                text notif


when isMainModule:
    setRenderer snackbar
