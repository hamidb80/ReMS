import std/[strformat]

import karax/[karaxdsl, vdom]

import ../../common/types

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

func invisibleText*: Vnode =
  ## used to fix inconsistent UI behaviours
  buildHtml:
    span(class = "invisible"):
      text "i"
