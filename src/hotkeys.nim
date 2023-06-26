
import std/[dom, jsffi]

type 
  HotKeyHandler* = ref object of JsObject

proc addHotkey*(
  keyCombination: cstring, 
  callback: proc(event: Event, handler: JsObject)
) {.importjs: "hotkeys(@)".}
