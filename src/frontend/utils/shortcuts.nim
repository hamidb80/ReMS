import std/strutils
import std/dom

import ./browser


type
  ShortCut* = object
    code*: KeyCode
    alt*, ctrl*, shift*: bool


func initShortCut*(e: KeyboardEvent): ShortCut =
  # release event is a little bit quirky
  let c = KeyCode e.keyCode
  ShortCut(
    code: c,
    alt: e.altKey or c == kcAlt,
    ctrl: e.ctrlKey or c == kcCtrl,
    shift: e.shiftKey or c == kcShift)

func initShortCut*(e: string): ShortCut =
  for k in splitwhitespace toLowerAscii e:
    case k
    of "alt":
      result.alt = true
      result.code = kcAlt
    of "ctrl":
      result.ctrl = true
      result.code = kcCtrl
    of "shift":
      result.shift = true
      result.code = kcShift
    of "del":
      result.code = kcDelete
    of "esc":
      result.code = kcEscape
    of "spc":
      result.code = kcSpace
    of "tab":
      result.code = kcTab
    else:
      if k.len == 1:
        result.code =
          case k[0]
          of '0'..'9', 'a'..'z':
            Keycode ord toupperAscii k[0]
          else:
            raise newException(ValueError, "not defined")

func sc*(e: string): ShortCut =
  initShortCut e
