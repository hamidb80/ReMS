import std/[tables, dom, jsffi]

import karax/[karaxdsl, vdom, vstyles, karax]

import ../../common/[types, conventions]
import ../../backend/database/[models, logic]
import ./simple


type
  GeneralCardButtonKind = enum
    gcbkLink
    gcbkAction

  GeneralCardButton* = object
    icon: string
    colorClass: string

    case kind: GeneralCardButtonKind
    of gcbkAction:
      isDangerous: bool
      action: proc()

    of gcbkLink:
      url: string


proc checkbox*(active: bool, changeHandler: proc(b: bool)): VNode =
  buildHtml:
    input(class = "form-check-input", `type` = "checkbox", checked = active):
      proc oninput(e: dom.Event, v: VNode) =
        changeHandler e.target.checked

# TODO check for show name
proc tagViewC*(
  t: Tag,
  value: SomeString,
  clickHandler: proc()
): VNode =
  buildHtml:
    tdiv(class = """d-inline-flex align-items-center py-2 px-3 mx-2 my-1 
      badge border-1 solid-border rounded-pill pointer""",
      onclick = clickHandler,
      style = style(
      (StyleAttr.background, toColorString t.theme.bg),
      (StyleAttr.color, toColorString t.theme.fg),
      (StyleAttr.borderColor, toColorString t.theme.fg),
    )):
      icon $t.icon

      if t.showName or t.hasValue:
        span(dir = "auto", class = "ms-2"):
          if t.showName:
            text t.label

          if t.hasValue:
            text ": "
            text value

func generalCardBtnLink*(icon, colorClass, url: string): GeneralCardButton =
  GeneralCardButton(
    icon: icon,
    colorClass: colorClass,
    kind: gcbkLink,
    url: url)

func generalCardBtnAction*(icon, colorClass: string,
    action: proc(), isDangerous = false): GeneralCardButton =
  GeneralCardButton(
    icon: icon,
    colorClass: colorClass,
    kind: gcbkAction,
    action: action,
    isDangerous: isDangerous)

proc generalCardButtonView(b: GeneralCardButton): VNode =
  let cls = "btn mx-1 btn-compact btn-outline-" & b.colorClass

  buildHtml:
    case b.kind
    of gcbkLink:
      a(class = cls, target = "_blank", href = b.url):
        icon b.icon
    
    of gcbkAction:
      button(class = cls, onclick = b.action):
        icon b.icon

proc generalCardView*(
  posterImageUrl: string,
  content: VNode,
  rels: openArray[RelMinData],
  tagsDB: Table[Str, Tag],
  btns: openArray[GeneralCardButton],
): VNode =
  buildHtml:
    tdiv(class = "masonry-item card my-3 border rounded bg-white"):
      if posterImageUrl != "":
        tdiv(class = "d-flex bg-light card-img justify-content-center overflow-hidden"):
          img(src = posterImageUrl)

      tdiv(class = "card-body"):
        content

        tdiv(class = "my-1"):
          for r in rels:
            tagViewC tagsDB[r.label], r.value, noop

      if btns.len != 0:
        tdiv(class = "card-footer d-flex justify-content-center"):
          for b in btns:
            generalCardButtonView b