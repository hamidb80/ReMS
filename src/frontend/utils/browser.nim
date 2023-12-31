import std/[dom, asyncjs, jsformdata]
import std/[sugar, with]
import ./js
import ../../common/[types]

type
  ProgressEvent* = ref object of Event
    loaded*: int
    total*: int
    lengthComputabl*: bool

  DFile* = dom.File

  KeyCode* = enum
    kcBackspace = 8
    kcTab = 9
    kcEnter = 13
    kcShift = 16
    kcCtrl = 17
    kcAlt = 18
    kcPauseBreak = 19
    kcCapsLock = 20
    kcEscape = 27
    kcSpace = 32
    kcPageUp = 33
    kcPageDown = 34
    kcEnd = 35
    kcHome = 36
    kcArrowLeft = 37
    kcArrowUp = 38
    kcArrowRight = 39
    kcArrowDown = 40
    kcPrintScreen = 44
    kcInsert = 45
    kcDelete = 46
    kc0 = 48
    kc1 = 49
    kc2 = 50
    kc3 = 51
    kc4 = 52
    kc5 = 53
    kc6 = 54
    kc7 = 55
    kc8 = 56
    kc9 = 57
    kcA = 65
    kcB = 66
    kcC = 67
    kcD = 68
    kcE = 69
    kcF = 70
    kcG = 71
    kcH = 72
    kcI = 73
    kcJ = 74
    kcK = 75
    kcL = 76
    kcM = 77
    kcN = 78
    kcO = 79
    kcP = 80
    kcQ = 81
    kcR = 82
    kcS = 83
    kcT = 84
    kcU = 85
    kcV = 86
    kcW = 87
    kcX = 88
    kcY = 89
    kcZ = 90
    kcLeftWindowKey = 91
    kcRightWindowKey = 92
    kcSelectKey = 93
    kcNumpad0 = 96
    kcNumpad1 = 97
    kcNumpad2 = 98
    kcNumpad3 = 99
    kcNumpad4 = 100
    kcNumpad5 = 101
    kcNumpad6 = 102
    kcNumpad7 = 103
    kcNumpad8 = 104
    kcNumpad9 = 105
    kcMultiply = 106
    kcAdd = 107
    kcSubtract = 109
    kcDecimalpoint = 110
    kcDivide = 111
    kcF1 = 112
    kcF2 = 113
    kcF3 = 114
    kcF4 = 115
    kcF5 = 116
    kcF6 = 117
    kcF7 = 118
    kcF8 = 119
    kcF9 = 120
    kcF10 = 121
    kcF11 = 122
    kcF12 = 123
    kcNumlock = 144
    kcScrollLock = 145
    kcMyComputer = 182
    kcMyCalculator = 183
    kcSemicolon = 186
    kcEqualsign = 187
    kcComma = 188
    kcDash = 189
    kcPeriod = 190
    kcForwardSlash = 191
    kcOpenbracket = 219
    kcBackSlash = 220
    kcCloseBraket = 221
    kcSingleQuote = 222

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

proc imageDataUrl(file: DFile): Future[cstring] =
  newPromise proc(resolve: proc(t: cstring); reject: proc(e: Event)) =
    var reader = newFileReader()
    reader.onload = (ev: Event) => resolve("ev.target.result") # resolve(ev.target.result)
    reader.onerror = reject
    reader.onabort = reject
    readAsDataURL reader, file

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

proc el*(id: cstring): Element =
  getElementById document, id

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

type
  ScreenOrient* = enum
    soPortrait
    soLandscape

proc screenOrientation*: ScreenOrient =
  if window.innerWidth > window.innerHeight: soLandscape
  else: soPortrait
