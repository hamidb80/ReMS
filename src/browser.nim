import std/[dom]


proc qi*(id: string): Element =
  document.getElementById id

proc downloadUrl*(name, data: cstring)
  {.importjs: "downloadUrl(@)".}

proc onNonPassive*(el: Element, eventName: cstring, handler: proc(e: Event)) =
  el.addEventListener(eventName, handler,
    AddEventListenerOptions(passive: false))

proc setTimeout*(delay: Natural, action: proc) =
  discard setTimeout(action, delay)
