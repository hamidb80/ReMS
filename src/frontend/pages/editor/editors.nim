import std/[jsffi, dom, jsconsole]
import karax/[karax, karaxdsl, vdom]
import core

proc textInput*(input: JsObject, cb: CallBack): VNode =
  buildHtml input(
    value = (input.to cstring),
    dir = "auto"):
    proc oninput(e: Event, n: VNode) =
      cb n.value.toJs

proc rawTextEditor*(input: JsObject, cb: CallBack): VNode =
  buildHtml textarea(
    value = (input.to cstring),
    dir = "auto"):
    proc oninput(e: Event, n: VNode) =
      cb n.value.toJs

proc checkBoxEditor*(input: JsObject, cb: CallBack): VNode =
  result = buildHtml input(
    class = "form-check-input bw-checkbox",
    `type` = "checkbox"):
    proc onchange(e: Event, n: VNode) =
      cb e.target.checked.toJs

  if input.to bool:
    result.setAttr "checked"


proc optionItem(val, txt: cstring, selected: bool): VNode =
  result = buildHtml:
    option(value = val):
      text txt

  if selected:
    result.setAttr "selected"

proc selectEditor*(input: JsObject, cb: CallBack): VNode =
  result = buildHtml select(class = "form-select"):
    for item in input["data"]:
      optionItem(
        item[0].to cstring,
        item[1].to cstring,
        item[0] == input["default"])

    proc oninput(e: Event, n: VNode) =
      cb e.target.value.tojs
