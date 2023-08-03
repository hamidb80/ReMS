
import std/[dom, jsffi]

type
  HotKeyHandler* = ref object of JsObject

proc addHotkey*(
  keyCombination: cstring,
  callback: proc(event: Event, handler: JsObject)
) {.importjs: "hotkeys(@)".}

proc addHotkey*(
  keyCombination: cstring,
  callback: proc(event: Event)
) {.importjs: "hotkeys(@)".}

proc addHotkey*(
  keyCombination: cstring,
  callback: proc()
) {.importjs: "hotkeys(@)".}
