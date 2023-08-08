import std/[with, strutils, sequtils, options]
import std/[dom, jsconsole, jsffi, jsfetch, asyncjs, sugar]
import karax/[karax, karaxdsl, vdom, vstyles]
import caster

import ../jslib/[hotkeys]
import ../utils/[browser, ui]


type
  ColorTheme = tuple
    bg, fg: string

  AppState = enum
    asInit
    asSelectIcon

  Tag = object
    name, icon, value: string
    theme: ColorTheme
    hasValue, showName: bool


const
  white: ColorTheme = ("#ffffff", "#889bad")
  smoke: ColorTheme = ("#ecedef", "#778696")
  road: ColorTheme = ("#dfe2e4", "#617288")
  yellow: ColorTheme = ("#fef5a6", "#958505")
  orange: ColorTheme = ("#ffdda9", "#a7690e")
  red: ColorTheme = ("#ffcfc9", "#b26156")
  peach: ColorTheme = ("#fbc4e2", "#af467e")
  pink: ColorTheme = ("#f3d2ff", "#7a5a86")
  purple: ColorTheme = ("#dac4fd", "#7453ab")
  purpleLow: ColorTheme = ("#d0d5fe", "#4e57a3")
  blue: ColorTheme = ("#b6e5ff", "#2d7aa5")
  diomand: ColorTheme = ("#adefe3", "#027b64")
  mint: ColorTheme = ("#c4fad6", "#298849")
  green: ColorTheme = ("#cbfbad", "#479417")
  lemon: ColorTheme = ("#e6f8a0", "#617900")

  icons = splitlines staticRead "./icons.txt"
  defaultIcon = icons[0]
  noIndex = -1
  defaultTag = Tag(
    icon: defaultIcon,
    theme: road,
    showName: true,
    name: "empty")

var
  state = asInit
  currentTag = defaultTag
  selectedTagI = noIndex
  tags = @[
    Tag(name: "Idea",
      icon: "fa-lightbulb",
      theme: pink,
      hasValue: false, showName: true),
    Tag(name: "Critical",
      icon: "fa-gun",
      theme: red,
      hasValue: false, showName: true),
    Tag(name: "Date",
      icon: "fa-clock",
      theme: blue,
      hasValue: true, showName: false),
    Tag(name: "Session",
      icon: "fa-chair",
      theme: lemon,
      hasValue: true, showName: false)]

proc onIconSelected(icon: string) =
  currentTag.icon = icon
  state = asInit

proc genChangeSelectedTagi(i: int): proc() =
  proc =
    if selectedTagI == i:
      selectedTagI = noIndex
      currentTag = defaultTag
    else:
      selectedTagI = i
      currentTag = tags[i]

proc noop = discard

proc tag(
  t: Tag,
  value: string,
  selected: bool,
  forceShowName: bool,
  clickHandler: proc()
): VNode =
  let showNameForce = forceShowName or t.showName

  buildHtml:
    tdiv(class = """d-inline-flex align-items-center py-2 px-3 mx-2 my-1 
      badge border-1 solid-border rounded-pill pointer""",
      onclick = clickHandler,
      style = style(
      (StyleAttr.background, t.theme.bg.cstring),
      (StyleAttr.color, t.theme.fg.cstring),
      (StyleAttr.borderColor, t.theme.fg.cstring),
    )):
      icon t.icon

      if showNameForce or t.hasValue:
        span(dir = "auto", class = "ms-2"):
          if showNameForce:
            text t.name

          if showNameForce and t.hasValue:
            text ": "

          if t.hasValue:
            text value

proc checkbox(checked: bool, changeHandler: proc(b: bool)): VNode =
  result = buildHtml:
    input(class = "form-check-input", `type` = "checkbox"):
      proc oninput(e: Event, v: Vnode) =
        changeHandler e.target.checked

  if checked:
    result.setAttr "checked"


proc iconSelectionBLock(icon: string, setIcon: proc(icon: string)): VNode =
  buildHtml:
    tdiv(class = "btn btn-lg btn-outline-dark rounded-2 m-1 p-2"):
      icon " m-2 " & icon
      proc onclick =
        setIcon icon


proc createDom: Vnode =
  result = buildHtml tdiv:
    nav(class = "navbar navbar-expand-lg bg-white"):
      tdiv(class = "container-fluid"):
        a(class = "navbar-brand", href = "#"):
          icon "fa-hashtag fa-xl me-3 ms-1"
          text "Tags"

    tdiv(class = "p-4 mx-4 my-2"):
      h6(class = "mb-3"):
        icon "fa-bars-staggered me-2"
        text "All Tags"

      tdiv(class = "d-flex flex-row"):
        for i, t in tags:
          tag(t, "val", t.icon == currentTag.icon, true,
              genChangeSelectedTagi i)

    tdiv(class = "p-4 mx-4 my-2"):
      h6(class = "mb-3"):
        icon "fa-gear me-2"
        text "Config"

      tdiv(class = "form-control"):
        if state == asSelectIcon:
          tdiv(class = "d-flex flex-row flex-wrap justify-content-between"):
            for c in icons:
              iconSelectionBLock(c, onIconSelected)

        else:
          # name
          tdiv(class = "form-group d-inline-block mx-2"):
            label(class = "form-check-label"):
              text "name: "

            input(`type` = "text", class = "form-control tag-input",
                value = currentTag.name):
              proc oninput(e: Event, v: Vnode) =
                currentTag.name = $e.target.value

          # icon
          tdiv(class = "form-check"):
            label(class = "form-check-label"):
              text "icon: "

            tdiv(class = "d-inline-block"):
              tdiv(class = "btn btn-lg btn-outline-dark rounded-2 m-2 p-2"):
                icon "m-2 " & currentTag.icon

              proc onclick =
                state = asSelectIcon

          # show name
          tdiv(class = "form-check form-switch"):
            checkbox(currentTag.showName,
              proc(b: bool) =
              currentTag.showName = b)

            label(class = "form-check-label"):
              text "show name"

          # has value
          tdiv(class = "form-check form-switch"):
            checkbox(currentTag.hasValue,
              proc (b: bool) =
              currentTag.hasValue = b)

            label(class = "form-check-label"):
              text "has value"

          # color theme
          # background
          tdiv(class = "form-group d-inline-block mx-2"):
            label(class = "form-check-label"):
              text "background color: "

            input(`type` = "color",
                class = "form-control",
                value = currentTag.theme.bg):
              proc oninput(e: Event, v: Vnode) =
                currentTag.theme.bg = $e.target.value

          # foreground
          tdiv(class = "form-group d-inline-block mx-2"):
            label(class = "form-check-label"):
              text "foreground color: "

            input(`type` = "color",
                class = "form-control",
                value = currentTag.theme.fg):
              proc oninput(e: Event, v: Vnode) =
                currentTag.theme.fg = $e.target.value

        # demo
        tdiv:
          tag(currentTag, "val", false, false, noop)

        if selectedTagI == noIndex:
          button(class = "btn btn-success w-100 mt-2 mb-4"):
            text "add"
            icon "mx-2 fa-plus"
        else:
          button(class = "btn btn-primary w-100 mt-2 mb-4"):
            text "update"
            icon "mx-2 fa-sync"


when isMainModule:
  setRenderer createDom
