import std/[strformat, strutils, sugar]
import std/[dom, jsconsole]
import karax/[karaxdsl, vdom, karax], caster
import conventions, browser


# --- components ---

func icon*(class: string): VNode =
  buildHtml:
    bold(class = "fa-solid fa-" & class)

func konva*(id: cstring): VNode =
  verbatim fmt"""
    <div id="{id}"></div>
  """

func invisibleText*: Vnode =
  ## used to fix inconsistent UI behaviours
  buildHtml:
    span(class = "invisible"):
      text "i"
