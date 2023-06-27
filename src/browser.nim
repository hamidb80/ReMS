import std/[dom]


proc qi*(id: string): Element =
  document.getElementById id

proc downloadUrl*(name, data: cstring)
  {.importjs: "downloadUrl(@)".}

let nonPassive* = AddEventListenerOptions(passive: false)

proc setTimeout*(delay: Natural, action: proc) =
  discard setTimeout(action, delay)
