import std/[tables, dom, jsffi]

import karax/[karaxdsl, vdom, vstyles, karax]

import ../../common/[types, conventions, str]
import ../../backend/database/[models, logic]
import ./simple


proc checkbox*(active: bool, changeHandler: proc(b: bool)): VNode =
  buildHtml:
    input(class = "form-check-input", `type` = "checkbox", checked = active):
      proc oninput(e: dom.Event, v: VNode) =
        changeHandler e.target.checked

