import std/[strformat, dom]
include karax/prelude
import karax/vstyles

func konva(id: cstring): VNode = 
  verbatim fmt"""
    <div id="{id}"></div>
  """

proc createDom*: VNode =
  let h = window.innerHeight

  buildHtml:
    tdiv(class = "d-flex flex-row"):
      main(class = "board-wrapper border border-dark rounded overflow-hidden"):
        konva "board"

      aside(class="side-bar position-absolute shadow-sm border bg-white h-100 overflow-hidden"):
        header(class="tabs"):
          ul(class = "nav nav-tabs"):

            li(class = "nav-item"):
              a(class = "nav-link active", href = "#home"):
                text "Home"

            li(class = "nav-item"):
              a(class = "nav-link", href = "#profile"):
                text "Profile"

        
        main(class="p-4 content-wrapper"):
          for i in 1..20:
            tdiv(class = "card mb-4"):
              tdiv(class = "card-body"):
                h4(class = "card-title"):
                  text "Card title"
                h6(class = "card-subtitle mb-2 text-muted"):
                  text "Card subtitle"
                p(class = "card-text"):
                  text """
        Some quick example text to build on the card title and make up the bulk of the
        card's content."""
                a(class = "card-link", href = "#"):
                  text "Card link"
                a(class = "card-link", href = "#"):
                  text "Another link"

