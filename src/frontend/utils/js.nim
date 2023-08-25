import std/[macros]
import std/[jsffi, asyncjs]

type
  JsSet = ref object of JsObject

func parseInt*(s: cstring): int {.importjs: "parseInt(@)".}
func parseFloat*(s: cstring): float {.importjs: "parseFloat(@)".}
func toLower*(s: cstring): cstring {.importjs: "#.toLowerCase()".}
proc parseJs*(s: cstring): JsObject {.importjs: "JSON.parse(@)".}
proc stringify*(s: JsObject): cstring {.importjs: "JSON.stringify(@)".}
func newJsArray*(): JsObject {.importjs: "[@]".}
func add*(a, b: JsObject) {.importjs: "#.push(#)".}

func newJsSet*(): JsSet {.importjs: "new Set(@)".}
func incl*(j: JsSet, c: cstring) {.importjs: "#.add(@)".}
iterator items*(obj: JsSet): cstring =
  var v: cstring
  {.emit: "for (`v` of `obj`) {".}
  yield v
  {.emit: "}".}

template c*(str): untyped = cstring str

template set*(container, value): untyped =
  container = value

proc setTimeout*(delay: Natural; action: proc) =
  discard setTimeout(action, delay)

proc newPromise*[T, E](action: proc(
  resovle: proc(t: T);
  reject: proc(e: E)
)): Future[T] {.importjs: "new Promise(@)".}

proc dthen*[T](f: Future[T]; resolve: proc(t: T)) =
  discard f.then resolve

proc dcatch*[T, E](f: Future[T]; catcher: proc(e: E)) =
  discard f.catch catcher

proc toJsRecursiveImpl(t: NimNode): NimNode =
  result = newStmtList()
  let temp = genSym()

  case t.kind
  of nnkCurly: # {}
    expectLen t, 0
    result = quote:
      newJsObject()

  of nnkTableConstr: # {a: 1, ...}
    result.add quote do:
      let `temp` = newJsObject()

    for ch in t:
      expectKind ch, nnkExprColonExpr
      let
        l = ch[0]
        r = ch[1]
        value = quote:
          toJsRecursive(`r`)

      result.add quote do:
        `temp`[`l`] = `value`

    result.add temp
    result = newBlockStmt result

  of nnkBracket: # [1, ...]
    result.add quote do:
      let `temp` = newJsArray()

    for ch in t:
      result.add quote do:
        `temp`.add(toJsRecursive(`ch`))

    result.add temp
    result = newBlockStmt result

  else: # "string-literal", ident, call, ...
    result = quote:
      tojs(`t`)

macro toJsRecursive*(expr): untyped =
  toJsRecursiveImpl expr

template `<*`*(expr): untyped =
  toJsRecursive expr

