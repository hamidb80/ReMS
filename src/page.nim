import karax/[vdom, karaxdsl]

# --- aliases ---

func extCss(url: string): VNode =
  buildHtml link(rel = "stylesheet", href = url)

func extJs(url: string, defered: bool = false): VNode =
  if defered:
    buildHtml script(src = url, `defer` = "")
  else:
    buildHtml script(src = url)

# --- pages ---

func index*(pageTitle: string): VNode =
  buildHtml html:
    head:
      meta(charset = "UTF-8")
      meta(name = "viewport", content = "width=device-width, initial-scale=1.0")
      title: text pageTitle

      extJs "https://unpkg.com/konva@9/konva.min.js"
      extJs "https://unpkg.com/hotkeys-js/dist/hotkeys.min.js"
      extJs "./page.js", true
      extJs "./script.js", true

      extCss "https://bootswatch.com/5/flatly/bootstrap.min.css"
      extCss "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css"
      extCss "./custom.css"

    body:
      tdiv(id = "app")


when isMainModule:
  writeFile "./dist/index.html":
    $ index "ReMS - Remembering Manangement System"
