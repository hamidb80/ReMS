import std/[dom, asyncjs, jsformdata]
import std/[sugar, with, macros]
import macroplus

import prettyvec

import ./js
import ../../common/[types]


type
  ProgressEvent* = ref object of Event
    loaded*: int
    total*: int
    lengthComputabl*: bool

  DFile* = dom.File

  KeyCode* = enum
    kcBackspace = (8, "Backspace")
    kcTab = (9, "Tab")
    kcEnter = (13, "Enter")
    kcShift = (16, "Shift")
    kcCtrl = (17, "Ctrl")
    kcAlt = (18, "Alt")
    kcPauseBreak = (19, "Pause Break")
    kcCapsLock = (20, "Caps Lock")
    kcEscape = (27, "Esc")
    kcSpace = (32, "Space")
    kcPageUp = (33, "page up")
    kcPageDown = (34, "page down")
    kcEnd = (35, "End")
    kcHome = (36, "Home")
    kcArrowLeft = (37, "↢")
    kcArrowUp = (38, "↥")
    kcArrowRight = (39, "↣")
    kcArrowDown = (40, "↧")
    kcPrintScreen = (44, "?")
    kcInsert = (45, "Insert")
    kcDelete = (46, "Delete")
    kc0 = (48, "0")
    kc1 = (49, "1")
    kc2 = (50, "2")
    kc3 = (51, "3")
    kc4 = (52, "4")
    kc5 = (53, "5")
    kc6 = (54, "6")
    kc7 = (55, "7")
    kc8 = (56, "8")
    kc9 = (57, "9")
    kcA = (65, "A")
    kcB = (66, "B")
    kcC = (67, "C")
    kcD = (68, "D")
    kcE = (69, "E")
    kcF = (70, "F")
    kcG = (71, "G")
    kcH = (72, "H")
    kcI = (73, "I")
    kcJ = (74, "J")
    kcK = (75, "K")
    kcL = (76, "L")
    kcM = (77, "M")
    kcN = (78, "N")
    kcO = (79, "O")
    kcP = (80, "P")
    kcQ = (81, "Q")
    kcR = (82, "R")
    kcS = (83, "S")
    kcT = (84, "T")
    kcU = (85, "U")
    kcV = (86, "V")
    kcW = (87, "W")
    kcX = (88, "X")
    kcY = (89, "Y")
    kcZ = (90, "Z")
    kcLeftWindowKey = (91, "")
    kcRightWindowKey = (92, "")
    kcSelectKey = (93, "")
    kcNumpad0 = (96, "numpad 0")
    kcNumpad1 = (97, "numpad 1")
    kcNumpad2 = (98, "numpad 2")
    kcNumpad3 = (99, "numpad 3")
    kcNumpad4 = (100, "numpad 4")
    kcNumpad5 = (101, "numpad 5")
    kcNumpad6 = (102, "numpad 6")
    kcNumpad7 = (103, "numpad 7")
    kcNumpad8 = (104, "numpad 8")
    kcNumpad9 = (105, "numpad 9")
    kcMultiply = (106, "numpad *")
    kcAdd = (107, "+")
    kcSubtract = (109, " -")
    kcDecimalpoint = (110, "")
    kcDivide = (111, "/")
    kcF1 = (112, "F1")
    kcF2 = (113, "F2")
    kcF3 = (114, "F3")
    kcF4 = (115, "F4")
    kcF5 = (116, "F5")
    kcF6 = (117, "F6")
    kcF7 = (118, "F7")
    kcF8 = (119, "F8")
    kcF9 = (120, "F9")
    kcF10 = (121, "F10")
    kcF11 = (122, "F11")
    kcF12 = (123, "F12")
    kcNumlock = (144, "")
    kcScrollLock = (145, "")
    kcMyComputer = (182, "")
    kcMyCalculator = (183, "")
    kcSemicolon = (186, ";")
    kcEqualsign = (187, "=")
    kcComma = (188, ",")
    kcDash = (189, "-")
    kcPeriod = (190, ".")
    kcForwardSlash = (191, "/")
    kcOpenbracket = (219, "[")
    kcBackSlash = (220, "\\")
    kcClosedBracket = (221, "]")
    kcSingleQuote = (222, "'")

  ScreenOrient* = enum
    soPortrait
    soLandscape


converter toInt*(k: KeyCode): int = k.int

let nonPassive* = AddEventListenerOptions(passive: false)

proc addEventListener*(el: Element, event: cstring,
    options: AddEventListenerOptions, action: proc(e: Event)
  ) =
  addEventListener el, event, action, options

func add*(self: FormData; name: cstring;
    value: Blob) {.importjs: "#.append(#, #)".}

func toForm*(name: cstring; file: Blob): FormData =
  result = newFormData()
  add result, name, file


template winEl*: untyped =
  window.document.body

proc valueAsNumber*[T](el: Element): T
  {.importjs: "#.valueAsNumber".}

proc filesArray*(d: DataTransfer or Element or Node or Event):
  seq[DFile] {.importjs: "Array.from(#.files)".}

proc openNewTab*(link: cstring)
  {.importjs: "window.open(@)".}

func clientPos*(t: Touch): Vector =
  v(t.clientX, t.clientY)

func distance*(ts: seq[Touch]): float =
  assert 2 == len ts
  len (clientPos ts[0]) - (clientPos ts[1])

proc getWindowQueryParam*(param: cstring): cstring {.importjs: """
    (new URLSearchParams(window.location.search)).get(@)
  """.}

proc prepend*(container, child: Node) {.importjs: "#.prepend(#)".}
# proc after*(adjacent, newNode: Node) {.importjs: "#.after(#)".}
proc before*(adjacent, newNode: Node) {.importjs: "#.before(#)".}
proc result*(f: FileReader): cstring {.importjs: "#.result".}
proc newBlob(content, mimeType: cstring): Blob {.importjs: "new Blob([#], {type: #})".}
proc createObjectURL(blob: Blob): cstring {.importjs: "URL.createObjectURL(@)".}
proc revokeObjectURL(url: cstring) {.importjs: "URL.revokeObjectURL(@)".}

func toInlineCss*[A, B: SomeString](
    s: openArray[tuple[prop: A; val: B]]): string =
  for (p, v) in s:
    add result, p
    add result, ": "
    add result, v
    add result, ";"

proc ql*(q: cstring): Element =
  querySelector document, q

proc el*(id: cstring): Element =
  getElementById document, id

proc setPageTitle*(title: cstring) {.importjs: "(document.title = @)".}

proc purge*(el: Element) =
  el.innerHTML = ""

proc ctrlClass*(el: Element; class: cstring; cond: bool) =
  if cond:
    add el.classList, class
  else:
    remove el.classList, class

proc toggleAttr*(el: Element; attr: cstring; cond: bool) =
  if cond:
    setAttr el, attr, ""
  else:
    removeAttribute el, attr


proc createElement*(tag: string): Element =
  createElement document, tag

proc downloadUrl*(name, dataurl: cstring) =
  let link = createElement "a"
  setAttr link, "href", dataurl
  setAttr link, "target", "_blank"
  setAttr link, "download", name
  click link

proc createElement*[A, B: SomeString](
  tag: string;
  attrs: openArray[tuple[key: A; val: B]]
): Element =

  result = createElement tag
  for (k, v) in attrs:
    setAttr result, k, v

proc append*(el: Element; children: varargs[Element]) =
  for ch in children:
    appendChild el, ch

proc appendTemp(el: Element; action: proc()) =
  appendChild document.body, el
  action()
  remove el

proc addEventListener*(et: EventTarget; ev: cstring; cb: proc())
  {.importjs: "#.addEventListener(@)".}

proc downloadFile*(fileName, mimeType, content: cstring) =
  runnableExamples:
    downloadFile "Hello, World!", "example.txt", "text/plain"

  let
    url = createObjectURL newBlob(content, mimeType)
    downloadEl = createElement("a", {"href": url, "download": fileName})

  appendTemp downloadEl, () => downloadEl.click
  revokeObjectURL url

proc selectFile*(action: proc(s: cstring)) =
  let fileInput = createElement("input", {"type": "file"})

  addEventListener fileInput, "input", proc(e: Event) =
    let
      files = e.target.InputElement.files
      file = files[0]
      reader = newFileReader()

    with reader:
      addEventListener "load", () => action reader.result
      readAsText file

  appendTemp fileInput, () => fileInput.click


proc copyToClipboard*(t: cstring)
  {.importjs: "navigator.clipboard.writeText(@);".}

proc text*(e: ClipboardEvent): cstring
  {.importjs: "  #.clipboardData.getData('text/plain')".}

proc redirect*(url: cstring)
  {.importjs: "location.href = #;".}

proc clsx*(el: Element, cond: bool, cls: cstring) = 
  if cond:
    el.classList.add cls
  else:
    el.classList.remove cls

proc appendTreeImpl(root, body: NimNode, acc: var NimNode)= 
    case kind body
    of nnkStmtList: 
        for node in body:
            appendTreeImpl root, node, acc
    
    of nnkCall: 
        for node in body[CallArgs]:
            appendTreeImpl body[CallIdent], node, acc
        appendTreeImpl root, body[CallIdent], acc

    of nnkIdent: 
        add acc, quote do:
            `root`.append `body`

    else: 
        doAssert false

macro appendTree*(root, body): untyped = 
    runnableExamples:
      appendTree mainEl:
          el1
          el2:
              el2_1:
                  el2_1_1
          el3:
              el3_1
              el3_2
              el3_3  

    result = newStmtList()
    appendTreeImpl root, body, result
  

proc screenOrientation*: ScreenOrient =
  if window.innerWidth > window.innerHeight: soLandscape
  else: soPortrait
