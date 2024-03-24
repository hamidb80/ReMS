import std/[strformat]

import karax/[karaxdsl, vdom]


func icon*(class: string): VNode =
  buildHtml:
    bold(class = "fa-solid " & class)

func iconr*(class: string): VNode =
  buildHtml:
    bold(class = "fa-regular " & class)

func verbatimElement*(id: string): VNode =
  verbatim fmt"""
    <div id="{id}"></div>
  """

func invisibleText*: VNode =
  ## used to fix inconsistent UI behaviours
  buildHtml:
    span(class = "invisible"):
      text "i"
