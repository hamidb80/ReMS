import std/[with, math, options, lenientops, strformat, random]
import std/[dom, jsconsole, jsffi, jsfetch, asyncjs, sugar]
import karax/[karax, karaxdsl, vdom, vstyles]
import caster

import ../[hotkeys, browser]


type
  ColorTheme = tuple
    bg, fg: string

const
  white: ColorTheme = ("#ffffff", "#889bad")
  smoke = ("#ecedef", "#778696")
  road = ("#dfe2e4", "#617288")
  yellow = ("#fef5a6", "#958505")
  orange = ("#ffdda9", "#a7690e")
  red = ("#ffcfc9", "#b26156")
  peach = ("#fbc4e2", "#af467e")
  pink = ("#f3d2ff", "#7a5a86")
  purple = ("#dac4fd", "#7453ab")
  purpleLow = ("#d0d5fe", "#4e57a3")
  blue = ("#b6e5ff", "#2d7aa5")
  diomand = ("#adefe3", "#027b64")
  mint = ("#c4fad6", "#298849")
  green = ("#cbfbad", "#479417")
  lemon = ("#e6f8a0", "#617900")

  icons  = [
    "fa-hashtag",
    "fa-clock",
    "fa-stopwatch",
    "fa-calendar",
    "fa-user",
    "fa-users",
    "fa-globe",
    "fa-heart",
    "fa-house",
    "fa-phone",
    "fa-sun",
    "fa-moon",
    "fa-tree",
    "fa-spa",
    "fa-seedling",
    "fa-plane",
    "fa-paper-plane",
    "fa-ruler",
    "fa-poop",
    "fa-gift",
    "fa-umbrella",
    "fa-bookmark",
    "fa-book",
    "fa-dna",
    "fa-life-ring",
    "fa-mug-saucer",
    "fa-quote-left",
    "fa-cookie-bite",
    "fa-dumbbell",
    "fa-fish",
    "fa-shapes",
    "fa-shield-halved",
    "fa-note-sticky",
    "fa-location-crosshairs",
    "fa-city",
    "fa-infinity",
    "fa-skull",
    "fa-graduation-cap",
    "fa-question",
    "fa-info",
    "fa-cloud",
    "fa-plug",
    "fa-pen",
    "fa-bolt",
    "fa-check",
    "fa-xmark",
    "fa-atom",
    "fa-ghost",
    "fa-vial",
    "fa-flask",
    "fa-face-laugh",
    "fa-face-smile",
    "fa-face-meh",
    "fa-face-sad-cry",
    "fa-face-surprise",
    "fa-face-angry",
    "fa-robot",
    "fa-feather",
    "fa-bed",
    "fa-code",
    "fa-filter",
    "fa-ellipsis",
    "fa-cube",
    "fa-circle-nodes",
    "fa-apple-whole",
    "fa-florin-sign",
    "fa-hands-clapping",
    "fa-hand-fist",
    "fa-anchor",
    "fa-microchip",
    "fa-paperclip",
    "fa-link",
    "fa-star",
    "fa-asterisk",
    "fa-thumbtack",
    "fa-person",
    "fa-palette",
    "fa-gamepad",
    "fa-marker",
    "fa-trophy",
    "fa-crown",
    "fa-recycle",
    "fa-satellite",
    "fa-satellite-dish",
    "fa-road-barrier",
    "fa-ribbon",
    "fa-mountain",
    "fa-mosque",
    "fa-microphone-lines",
    "fa-lock",
    "fa-lock-open",
    "fa-ice-cream",
    "fa-hourglass-end",
    "fa-helicopter",
    "fa-gun",
    "fa-gem",
    "fa-fan",
    "fa-explosion",
    "fa-couch",
    "fa-chess-knight",
    "fa-meteor",
    "fa-bomb",
    "fa-triangle-exclamation",
    "fa-radiation",
    "fa-comment",
    "fa-glasses",
    "fa-lightbulb",
    "fa-compass",
    "fa-location-dot",
    "fa-map-pin",
    "fa-key",
    "fa-snowflake",
    "fa-stairs",
    "fa-fire",
    "fa-file-lines",
    "fa-bell",
    "fa-filter",]

func tag(name: string, c: ColorTheme, selected: bool): VNode =
  buildHtml:
    tdiv(class = "badge border-1 solid-border rounded-pill mx-2 my-1 pointer",
      style = style(
      (StyleAttr.background, c.bg.cstring),
      (StyleAttr.color, c.fg.cstring),
      (StyleAttr.borderColor, c.fg.cstring),
    )):
      italic(class = "fa-solid fa-hashtag me-2")
      span:
        text name

proc createDom: Vnode =
  result = buildHtml tdiv:
    nav(class = "navbar navbar-expand-lg bg-light"):
      tdiv(class = "container-fluid"):
        a(class = "navbar-brand", href = "#"):
          italic(class = "fa-solid fa-hashtag fa-xl me-3 ms-1")
          text "Tags"

    tdiv(class = "p-4 mx-4 my-2"):
      h6(class = "mb-3"):
        italic(class = "fa-solid fa-bars-staggered me-2")
        text "All Tags"

      tdiv(class = "d-flex flex-row"):
        tag("hey", lemon, true)
        tag("hey", blue, false)
        tag("hey", peach, false)

    tdiv(class = "p-4 mx-4 my-2"):
      h6(class = "mb-3"):
        italic(class = "fa-solid fa-gear me-2")
        text "Config"

      tdiv(class = "form-control"):
        # name
        tdiv(class = "form-group d-inline-block mx-2"):
          label(class = "form-check-label"):
            text "name: "

          input(`type` = "text", class = "form-control tag-input")

        # icon
        if state == asChooseIcon:
          tdiv(class = "d-flex flex-row flex-wrap justify-content-between"):
            for c in icons:
              tdiv(class = "btn btn-lg btn-outline-dark rounded-2 m-2 p-2"):
                italic(class = "m-2 fa-solid " & c)
        else:
          discard

        # show name
        tdiv(class = "form-check form-switch"):
          input(class = "form-check-input", `type` = "checkbox")
          label(class = "form-check-label"):
            text "show name"

        # has value
        tdiv(class = "form-check form-switch"):
          input(class = "form-check-input", `type` = "checkbox")
          label(class = "form-check-label"):
            text "has value"

        tdiv(class = "form-group d-inline-block mx-2"):
          label(class = "form-check-label"):
            text "background color: "

          input(`type` = "color", class = "form-control")

        tdiv(class = "form-group d-inline-block mx-2"):
          label(class = "form-check-label"):
            text "foreground color: "

          input(`type` = "color", class = "form-control")


      # ------------- demo ----------------

      # if select == none:
      #   btn "add"
      # else: "update"

when isMainModule:
  setRenderer createDom
