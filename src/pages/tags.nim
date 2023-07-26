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


func tag(name: string, c: ColorTheme, selected: bool): VNode =
  buildHtml:
    tdiv(class = "badge border-1 solid-border rounded-pill mx-2 my-1 pointer", style = style(
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
      h6(class="mb-3"):
        italic(class = "fa-solid fa-bars-staggered me-2")
        text "All Tags"

      tdiv(class="d-flex flex-row"):
        tag("hey", lemon, true)
        tag("hey", blue, false)
        tag("hey", peach, false)

    tdiv(class = "p-4 mx-4 my-2"):
      h6(class="mb-3"):
        italic(class = "fa-solid fa-gear me-2")
        text "Config"

      # TODO
      # name
      # icon - select from a grid list
      # show name
      # have value

      # bg color
      # fg color

      # demo

      if select == none:
        btn "add"

when isMainModule:
  setRenderer createDom
