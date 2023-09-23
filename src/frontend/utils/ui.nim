import std/[dom]
import std/[strformat]

import karax/[karax, karaxdsl, vdom, vstyles]

import ../../common/types
import ../../backend/database/[models]

# --- components ---

func icon*(class: string): VNode =
  buildHtml:
    bold(class = "fa-solid " & class)

func iconr*(class: string): VNode =
  buildHtml:
    bold(class = "fa-regular " & class)

func konva*(id: string): VNode =
  verbatim fmt"""
    <div id="{id}"></div>
  """

func invisibleText*: VNode =
  ## used to fix inconsistent UI behaviours
  buildHtml:
    span(class = "invisible"):
      text "i"

proc tagViewC*(
  t: Tag,
  value: SomeString,
  clickHandler: proc()
): VNode =
  # TODO check for show name

  buildHtml:
    tdiv(class = """d-inline-flex align-items-center py-2 px-3 mx-2 my-1 
      badge border-1 solid-border rounded-pill pointer""",
      onclick = clickHandler,
      style = style(
      (StyleAttr.background, toColorString t.theme.bg),
      (StyleAttr.color, toColorString t.theme.fg),
      (StyleAttr.borderColor, toColorString t.theme.fg),
    )):
      icon $t.icon

      if t.showName or t.hasValue:
        span(dir = "auto", class = "ms-2"):
          if t.showName:
            text t.name

          if t.hasValue:
            text ": "
            text value

proc checkbox*(active: bool, changeHandler: proc(b: bool)): VNode =
  result = buildHtml:
    input(class = "form-check-input", `type` = "checkbox", checked = active):
      proc oninput(e: Event, v: VNode) =
        changeHandler e.target.checked
