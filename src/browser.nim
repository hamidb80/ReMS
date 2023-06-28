import std/[dom]


proc qi*(id: string): Element =
  document.getElementById id

template winEl*: untyped =
  window.document.body

proc downloadUrl*(name, data: cstring)
  {.importjs: "downloadUrl(@)".}

let nonPassive* = AddEventListenerOptions(passive: false)

proc setTimeout*(delay: Natural, action: proc) =
  discard setTimeout(action, delay)
