import std/[dom, cstrutils, jsffi]

import karax/[karax, karaxdsl, vdom]
import caster

import ../../utils/[browser, api]
import core


proc textInput*(input: JsObject, cb: CallBack): VNode =
  buildHtml input(
    class = "form-control",
    value = (input.to cstring),
    dir = "auto"):
    proc oninput(e: Event, n: VNode) =
      cb n.value.toJs

proc rawTextEditor*(input: JsObject, cb: CallBack): VNode =
  buildHtml textarea(
    class = "form-control h40v",
    value = (input.to cstring),
    dir = "auto"):
    proc oninput(e: Event, n: VNode) =
      cb n.value.toJs

proc checkBoxEditor*(input: JsObject, cb: CallBack): VNode =
  result = buildHtml input(
    class = "form-check-input bw-checkbox form-control",
    `type` = "checkbox",
    checked = input.to bool):
    proc onchange(e: Event, n: VNode) =
      cb e.target.checked.toJs

proc imageLinkOrUploadOnPasteInput*(input: JsObject, cb: CallBack): VNode =
  result = buildHtml input(
    class = "form-control",
    `type` = "text",
    value = (input.to cstring),
    placeholder = "paste image or link to image"):
    proc pasteHandler(e: dom.Event as ClipboardEvent) {.caster.} =
      let files = e.clipboardData.filesArray

      if files.len == 1: # paste by image
        let f = files[0]

        if f.`type`.startswith "image/":
          cb toJs "loading..."

          apiUploadAsset toForm(f.name, f), proc(assetUrl: string) =
            blur e.target.Element
            cb toJs assetUrl

    proc onfocus =
      addEventListener document.body, "paste", pasteHandler

    proc onblur =
      removeEventListener document.body, "paste", pasteHandler


proc optionItem(val, txt: cstring, selected: bool): VNode =
  result = buildHtml:
    option(value = val, selected = selected):
      text txt

proc selectEditor*(input: JsObject, cb: CallBack): VNode =
  result = buildHtml select(class = "form-select form-control"):
    for item in input["data"]:
      optionItem(
        item[0].to cstring,
        item[1].to cstring,
        item[0] == input["default"])

    proc oninput(e: Event, n: VNode) =
      cb e.target.value.tojs
