import std/[jsffi, dom, jsconsole]
import karax/[karax, karaxdsl, vdom]
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
