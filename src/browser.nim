import std/[dom]


proc qi*(id: string): Element =
  document.getElementById id

proc download*(data, memetype: cstring)
  {.importjs: "download(@)".}

proc downloadUrl*(name, data: cstring)
  {.importjs: "downloadUrl(@)".}


proc onNonPassive*(el: Element, eventName: cstring, handler: proc(e: Event)) =
  el.addEventListener(eventName, handler,
    AddEventListenerOptions(passive: false))
