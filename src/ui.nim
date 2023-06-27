import std/[strformat]
import  karax/[karaxdsl, vdom]


func icon(class: string): VNode =
  buildHtml:
    bold(class = "fa fa-" & class)

func konva(id: cstring): VNode =
  verbatim fmt"""
    <div id="{id}"></div>
  """

func createDom*: VNode =
  buildHtml:
    tdiv(class = "karax"):
      main(class = "board-wrapper border border-dark rounded overflow-hidden"):
        konva "board"

      aside(class = "side-bar position-absolute shadow-sm border bg-white h-100 d-flex flex-column"):
        header(class = "tabs"):
          tdiv(class = "nav nav-tabs d-flex flex-row justify-content-between"):

            tdiv(class = "d-flex flex-row"):
              tdiv(class = "nav-item"):
                a(class = "nav-link active", href = "#home"):
                  text "Messages"
                  # icon ""

              tdiv(class = "nav-item"):
                a(class = "nav-link", href = "#profile"):
                  text "Settings "
                  # icon ""

            tdiv(class = "nav-item"):
              span(class = "nav-link text-danger", role="button"):
                icon "times"

        main(class = "p-4 content-wrapper"):
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

func index*: VNode = 
  buildHtml:
    html(lang = "en"):
      head:
        meta(charset = "UTF-8")
        meta(content = "width=device-width, initial-scale=1.0", name = "viewport")
        title:
          text "RMS - Remembering Manangement System"
        script(src = "https://unpkg.com/konva@9/konva.min.js")
        script(src = "https://unpkg.com/hotkeys-js/dist/hotkeys.min.js")
        script(src = "./page.js", `defer` = "")
        script(src = "./script.js", `defer` = "")
        link(rel = "stylesheet", href = "https://bootswatch.com/5/flatly/bootstrap.min.css")
        link(rel = "stylesheet", href = "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css")
        link(rel = "stylesheet", href = "./custom.css")
      body:
        tdiv(id = "app")


when isMainModule:
  writeFile "./dist/index.html", $index()