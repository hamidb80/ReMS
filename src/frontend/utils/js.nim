import std/[macros, options]
import std/[jsffi, asyncjs, dom]

import ../../common/conventions

type
  JsSet = ref object of JsObject

func parseInt*(s: cstring): int
  {.importjs: "parseInt(@)".}

func parseFloat*(s: cstring): float
  {.importjs: "parseFloat(@)".}

func cleanStr*(n: float): cstring
  {.importjs: "(#).toString()".}

func cstr*(n: int): cstring
  {.importjs: "(#).toString()".}

func toLower*(s: cstring): cstring
  {.importjs: "#.toLowerCase()".}

proc parseJs*(s: cstring): JsObject
  {.importjs: "JSON.parse(@)".}

proc stringify*(s: JsObject): cstring
  {.importjs: "JSON.stringify(@)".}

func newJsArray*(): JsObject
  {.importjs: "[@]".}

func add*(a, b: JsObject)
  {.importjs: "#.push(#)".}

func toCstring*(a: SomeNumber): cstring
  {.importjs: "#.toString(@)".}

func splitLines*(s: cstring): seq[cstring]
  {.importjs: "#.split('\\n')".}

func find*(str, sub: cstring): int
  {.importjs: "#.indexOf(#)".}

func rfind*(str, sub: cstring): int
  {.importjs: "#.lastIndexOf(#)".}

proc unscape*(s: cstring): cstring
  {.importjs: "JSON.parse('@')".}

proc substr(str: cstring, start, ende: int): cstring
  {.importjs: "#.substring(@)".}

proc `[]`*(str: cstring, rng: Slice[int]): cstring =
  str.substr rng.a, rng.b+1

proc waitAll*(promises: seq[Future], cb: proc(), fail: proc() = noop) {.importjs: "Promise.all(#).then(#).catch(#)".}

func newJsSet*(): JsSet 
  {.importjs: "new Set(@)".}

func incl*(j: JsSet, c: cstring) 
  {.importjs: "#.add(@)".}

iterator items*(obj: JsSet): cstring =
  var v: cstring
  {.emit: "for (`v` of `obj`) {".}
  yield v
  {.emit: "}".}


template c*(str): untyped = 
  cstring str

func forceJsObject*(t: auto): JsObject 
  {.importjs: "(@)".}

template set*(container, value): untyped =
  container = value

proc setTimeout*(delay: Natural, action: proc): TimeOut {.discardable.} =
  setTimeout action, delay

proc newPromise*[T, E](action: proc(
  resovle: proc(t: T);
  reject: proc(e: E)
)): Future[T] 
  {.importjs: "new Promise(@)".}


proc then*[T](f: Future[T]; resolve: proc()): Future[void]
  {.importjs: "#.then(@)".}

proc then*[T](f: Future[T]; resolve: proc(t: T)): Future[void]
  {.importjs: "#.then(@)".}

proc then*[A, B](f: Future[A]; resolve: proc(t: A): B): Future[B]
  {.importjs: "#.then(@)".}

proc catch*[T](f: Future[T]; catcher: proc()): Future[void]
  {.importjs: "#.catch(@)".}

proc catch*[T](f: Future[T]; catcher: proc(t: T)): Future[void]
  {.importjs: "#.catch(@)".}

# proc catche*[T, E](f: Future[T]; catcher: proc(e: E)): Future[void]
  # {.importjs: "#.catch(@)".}

template dthen*(fut, cb): untyped =
  discard fut.then(cb)

template dcatch*(fut, cb): untyped =
  discard fut.catch(cb)


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
