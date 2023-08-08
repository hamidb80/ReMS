import std/[strformat]
import karax/[karaxdsl, vdom]

# --- components ---

func icon*(class: string): VNode =
  buildHtml:
    bold(class = "fa-solid " & class)

func konva*(id: cstring): VNode =
  verbatim fmt"""
    <div id="{id}"></div>
  """

func invisibleText*: Vnode =
  ## used to fix inconsistent UI behaviours
  buildHtml:
    span(class = "invisible"):
      text "i"
