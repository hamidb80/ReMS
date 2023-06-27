import std/strformat
include karax/prelude

func konva(id: cstring): VNode = 
  verbatim fmt"""
    <div id="{id}"></div>
  """

func createDom*: VNode =
  buildHtml:
    tdiv(class = "d-flex flex-row"):
      main(class = "border border-dark rounded overflow-hidden"):
        konva "board"

      aside:
        discard
