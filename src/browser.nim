import std/[dom]


proc qi*(id: string): Element =
  document.getElementById id

template winEl*: untyped =
  window.document.body

proc downloadUrl*(name, data: cstring)
  {.importjs: "downloadUrl(@)".}

proc valueAsNumber*[T](el: Element): T {.importjs: "#.valueAsNumber".}

let nonPassive* = AddEventListenerOptions(passive: false)

proc setTimeout*(delay: Natural, action: proc) =
  discard setTimeout(action, delay)
