import std/[sequtils, strutils, sets, with, strformat, sugar, algorithm, tables, math]
import std/[dom, jsffi]

import karax/[karax, karaxdsl, vdom, vstyles]
import questionable, caster
import prettyvec

import ../../../backend/database/[models]
import ./[core, components, inputs]
import ../../utils/[js, browser, api]
import ../../components/[snackbar, simple]
import ../../../common/[conventions, datastructures, types, iter]

type
  ViewMode = enum
    vmBothHorizontal
    vmBothVertical
    vmEditorOnly
    vmPreviewOnly

  BlockStyles = tuple
    wrapperCls: cstring
    extenderCls: cstring
    cssProperty: StyleAttr

    editorCls: cstring
    editorSize: int

    contentCls: cstring
    contentSize: int


const
  scrollStep = 100
  renderResultId = "tw-render"
  treeViewId = "tw-tree-view"
  porpertySettingId = "tw-property-setting"
  settingsAreaId = "tw-settings-area"
  extenderId = "tw-extender"
  editRootElementId = "tw-editor-root-element"
  searchComponentInputId = "tw-search-component-input"

var
  app = App(state: asTreeView)
  sidebarWidth = 300
  sidebarHeight = 300
  viewMode = vmBothHorizontal

# TODO app ability to copy node path
# TODO ability to add/remove tags here
# TODO import to a specific node not replace the whole tree!

# ----- UI ------------------------------

proc scrollContentTo(n: TwNode) =
  let
    n = app.focusedNode.dom
    d = el renderResultId
    scroll = d.scrollTop
    offy = n.offsetTop

  d.scrollTop = offy - d.offsetTop

proc isSeeingContent(n: TwNode): bool =
  let
    d = el renderResultId
    h = n.dom.offsetHeight
    o = n.dom.offsetTop - d.offsetTop
    view = (0 ..< d.offsetHeight) + d.scrollTop
    content = (o ..< o+h)

  intersects view, content

proc changeFocusNode(n: TwNode) =
  app.focusedNode = n
  if not isSeeingContent app.focusedNode:
    scrollContentTo app.focusedNode


proc setSideBarSize(x: int) =
  sidebarWidth = clamp(x, 100 .. window.innerWidth - 200)
  sidebarHeight = clamp(x, 100 .. window.innerHeight - 160)

proc saveServer =
  let id = parseInt getWindowQueryParam "id"
  apiUpdateNoteContent id, serialize app, proc =
    notify "note updated!"

func cls(hovered: bool, path: TreePath, selected: HashSet[TreePath],
    active: string): string =
  if hovered: active
  elif path in selected: "bg-info"
  else: "bg-light"

func pathId(path: TreePath): string =
  "tw-subtree-" & path.join"-"

proc recursiveListImpl(
  node: TwNode,
  path: var TreePath,
  hover: TreePath,
  selected: Hashset[TreePath]
): VNode =
  let hovered = hover == path

  buildHtml tdiv(id = pathId path, class = "tw-pointer"):
    let
      s = node.status
      t =
        case s.code
        of tsSuccess: "text-success"
        of tsWarning: "text-warning"
        of tsError: "text-danger"
        else: "text-muted"

      c =
        case s.code
        of tsLoading, tsInfo: "bg-info"
        of tsSuccess: "bg-success"
        of tsWarning: "bg-warning"
        of tsError: "bg-danger"
        else: "bg-primary"

      i =
        case s.code
        of tsLoading: "bi bi-hourglass-split"
        of tsInfo: "bi bi-info-circle-fill"
        of tsWarning: "bi bi-exclamation-triangle-fill"
        of tsError: "bi bi-x-circle-fill"
        else: ""


    tdiv(class = "tw-tree-indicator w-100 " &
      iff(hovered and app.insertionMode == imBefore, "bg-primary"))

    h6(class = "badge text-start px-2 w-100 my-0 " & cls(
        hovered and app.insertionMode == imAppend, path, selected, c)):
      proc onMouseEnter = node.hover()
      proc onMouseLeave = node.unhover()

      italic(class =
        if node.isLeaf: "bi bi-asterisk"
        elif node.data.visibleChildren: "bi bi-caret-down-fill"
        else: "bi bi-caret-right-fill"):

        proc onclick =
          negate node.data.visibleChildren
          redraw()

      tdiv(class = "d-inline-flex w-100 justify-content-between "):
        span(class = "user-select-none"):
          italic(class = "mx-2 " & node.data.component.icon)
          text node.data.component.name

        span(class = "me-2 " & iff(hovered, "", t)):
          if s.code != tsNothing:
            text s.msg
            italic(class = i & " mx-1")

          elif not isRoot node:
            text node.father.role path[^1]

        let p = path
        proc onclick =
          blur app.focusedNode
          app.focusedPath = p
          changeFocusNode node
          focus app.focusedNode
          app.insertionMode = imAppend
          redraw()

        proc ondblclick =
          app.state = asSetting

    if node.data.visibleChildren:
      for i, n in node.children:
        (path.add i)
        tdiv(class = "branch ms-4"):
          recursiveListImpl n, path, hover, selected
        (path.npop)

    tdiv(class = "tw-tree-indicator w-100 " &
      iff(hovered and app.insertionMode == imAfter, "bg-primary"))

proc recursiveList(data: TwNode): VNode =
  var treepath = newSeq[int]()
  recursiveListImpl data, treepath, app.focusedPath, app.selected

proc resetApp(root: TwNode) =
  app.tree = root
  app.focusedNode = root
  app.focusedPath = @[]

proc blocksStyleCtrl(viewMode: ViewMode): BlockStyles =
  let
    w = StyleAttr.width
    h = StyleAttr.height

  case viewMode
  of vmBothHorizontal: ("flex-row", "h-100", w, "h-100 ", sidebarWidth, "",
      window.innerWidth - sidebarwidth)
  of vmBothVertical: ("flex-column", "w-100", h, "w-100 ", sidebarHeight, "",
      window.innerHeight - sidebarwidth)
  of vmEditorOnly: ("", "", w, "h-100 ", window.innerWidth, "d-none", 0)
  of vmPreviewOnly: ("", "", w, "d-none", 0, "h-100", window.innerWidth)

# ----- Events ------------------------------

proc switchToTreeView =
  app.state = asTreeView

proc changeViewMove =
  incRound viewMode

proc prepareComponentSelection(node: TwNode) =
  let parentNode =
    case app.insertionMode
    of imAppend: node
    else: node.father

  reset app.availableComponents
  reset app.listIndex

  var acc = newJsSet()
  for t in parentNode.acceptsAsChild:
    for cname in app.componentsByTags[t]:
      acc.incl cname

  for cname in acc:
    if cname in app.components:
      app.availableComponents.add app.components[cname]

proc setState(newState: AppState) =
  if newState == asSelectComponent:
    setTimeout 100, proc =
      focus el searchComponentInputId
      app.filteredComponents = app.availableComponents
      app.filterString = cstring""
      redraw()

  app.state = newState

proc startInsertAtEnd =
  setState asSelectComponent
  prepareComponentSelection app.focusedNode

proc changeInsertionMode(mode: InsertionMode) =
  app.insertionMode =
    case app.insertionMode
    of imAppend: mode
    else: imAppend

proc setInsertBefore =
  changeInsertionMode imBefore

proc setInsertAfter =
  changeInsertionMode imAfter

proc moveSelectedNodes =
  let
    paths = app.selected.toseq.sorted
    h = paths.high
    i = app.focusedPath[^1]

  var nodes = newSeq[TwNode](paths.len)

  for i, p in reversed paths: # iterating in reverse order prevents index error
    let
      n = app.tree.follow p
      f = n.father
      ip = p.last

    detachNode f, ip
    nodes[h-i] = n

  case app.insertionMode
  of imAppend:
    for n in nodes:
      let size = app.focusedNode.children.len
      app.focusedNode.attach n, size

  of imAfter:
    for n in ritems nodes:
      app.focusedNode.father.attach n, i+1

  of imBefore:
    for n in ritems nodes:
      app.focusedNode.father.attach n, i

  reset app.selected
  app.state = asTreeView


proc createInstance(listIndex: int) =
  var newNode = instantiate(app.filteredComponents[listIndex], app.components)
  discard render newNode

  template i: untyped = app.focusedPath[^1]

  case app.insertionMode
  of imAppend:
    let size = app.focusedNode.children.len
    app.focusedNode.attach newNode, size
    app.focusedPath.add size

  of imAfter:
    app.focusedNode.father.attach newNode, i+1
    app.focusedPath[^1] += 1

  of imBefore:
    app.focusedNode.father.attach newNode, i

  newNode.mounted(mbUser, tmInteractive)
  app.focusedNode = newNode
  app.state = asTreeView
  app.insertionMode = imAppend

proc deleteSelectedNode(n: TwNode, path: TreePath) =
  if not isRoot n:
    let
      i = path[^1]
      f = n.father
    die n
    detachNode f, i

proc deleteSelectedNodes =
  let
    n = app.focusedNode
    i = app.focusedPath.last
    f = n.father

  if 0 != len app.selected:
    for e in app.selected.toseq.sorted.reversed:
      let d = app.tree.follow e
      deleteSelectedNode d, e
      # TODO where shoud put the parent?
    reset app.selected

  else:
    deleteSelectedNode n, app.focusedPath
    app.focusedPath.npop

    if 0 == f.children.len:
      changeFocusNode f
    else:
      let i2 = clamp(i-1, 0, f.children.high)
      app.focusedPath.add i2
      changeFocusNode f.children[i2]

proc moveToUp =
  if app.focusedPath.len > 0:
    if app.focusedPath[^1] == 0:
      discard
    else:
      dec app.focusedPath[^1]
      changeFocusNode app.focusedNode.father.children[app.focusedPath[^1]]

proc moveToDown =
  if app.focusedPath.len > 0:
    if app.focusedPath[^1] + 1 == app.focusedNode.father.children.len:
      discard
    else:
      app.focusedPath[^1].inc
      changeFocusNode app.focusedNode.father.children[app.focusedPath[^1]]

proc keyboardListener(e: Event as KeyboardEvent) {.caster.} =
  let lastFocus = app.focusedNode

  case app.state
  of asTreeView:
    case e.keyCode.KeyCode
    of kcArrowUp: # goes up
      preventDefault e
      moveToUp()

    of kcArrowDown: # goes down
      preventDefault e
      moveToDown()

    of kcArrowLeft: # goes outside
      if app.focusedPath.len > 0:
        app.focusedPath.npop
        changeFocusNode app.focusedNode.father

    of kcArrowRight: # goes inside
      if not app.focusedNode.isLeaf and app.focusedNode.data.visibleChildren:
        add app.focusedPath, 0
        changeFocusNode app.focusedNode.children[0]

    of kcOpenbracket: # insert before
      setInsertBefore()

    of kcClosedBracket: # insert after
      setInsertAfter()

    of kcDelete: # delete node
      deleteSelectedNodes()

    of kcEnter:
      if app.state == asTreeView and app.insertionMode == imAppend:
        app.state = asSetting

    of kcEscape:
      reset app.selected
      reset app.insertionMode

    of kcN: # insert inside
      startInsertAtEnd()

    of kcV: # change view mode
      changeViewMove()

    of kcM: # mark
      if app.focusedPath in app.selected:
        app.selected.excl app.focusedPath
      else:
        app.selected.incl app.focusedPath

    of kcT:
      negate app.focusedNode.data.visibleChildren

    of kcQ: # to query children of focued node like XPath like VIM editor
      discard

    of kcJ: # go down
      let d = el renderResultId
      d.scrollTop = d.scrollTop + scrollStep

    of kcK: # go up
      let d = el renderResultId
      d.scrollTop = d.scrollTop - scrollStep

    of kcW: # scroll to into the content
      scrollContentTo app.focusedNode

    of kcA: # show actions of focused element
      discard

    of kcD: # download as JSON
      downloadFile "data.json", "application/json",
        stringify forceJsObject serialize app

    of kcS: # save
      saveServer()

    of kcH: # download as HTML
      proc afterLoad(t: TwNode) =
        downloadFile "data.html", "text/html", t.dom.innerHTML

      # take a copy
      deserizalize(app.components, serialize app)
      .dthen(afterLoad)

    of kcU: # undo
      discard

    of kcR: # redo
      discard

    of kcO: # opens file
      selectFile proc(c: cstring) =
        purge app.tree.dom

        let data = cast[TreeNodeRaw[JsObject]](parseJs c)

        proc done(t: TwNode) =
          resetApp t
          redraw()

        deserizalize(app.components, data, some app.tree.dom)
        .then(done)
        .dcatch () => notify "could not load the file"

    else: discard

  of asSetting:
    case e.keyCode.KeyCode
    of kcEscape:
      if document.activeElement == document.body:
        app.state = asTreeView
      else:
        blur document.activeElement

    else: discard

  of asSelectComponent:
    case e.keycode.KeyCode
    of kcArrowLeft, kcArrowRight:
      e.preventDefault

    of kcArrowUp:
      app.listIndex = max(0, app.listIndex-1)

    of kcArrowDown:
      app.listIndex = min(app.availableComponents.high, app.listIndex+1)

    of kcEscape:
      app.state = asTreeView

    of kcEnter:
      createInstance app.listIndex

    of kcX:
      moveSelectedNodes()

    else:
      discard

  redraw()

  if lastFocus != app.focusedNode:
    blur lastFocus
    focus app.focusedNode

    let
      t = el pathId app.focusedPath
      w = el treeViewId

    w.scrollTop = t.offsetTop - 160

# ----- Init ------------------------------

proc fetchNote(id: Id) =
  proc done(tw: TwNode) =
    resetApp tw
    redraw()

  proc whenGet(n: NoteItemView) =
    deserizalize(app.components, n.data, some app.tree.dom, wait = false)
    .then(done)
    .dcatch proc =
      notify "failed to fetch note data"

  apiGetNote id, whenGet, proc =
    echo "error when fetching note", getcurrentExceptionmsg()

proc genSelectComponent(i: int): proc() =
  proc =
    createInstance i

proc sidebtn(icn: string, action: proc()): VNode =
  buildHtml button(
    class = "btn btn-outline-primary my-1 rounded px-2 py-3",
    onclick = action):
    icon "fa-xl " & icn

proc onPointerDown(e: Event) =
  # setCursor ccresizex
  proc movimpl(x, y: int) {.caster.} =
    case viewMode
    of vmBothHorizontal: setSideBarSize x
    of vmBothVertical: setSideBarSize y
    else: discard
    redraw()

  proc movMouse(e: Event as MouseEvent) {.caster.} =
    movimpl e.x, e.y

  proc moveTouch(ev: Event as TouchEvent) {.caster.} =
    let t = clientPos ev.touches[0]
    movimpl |t.x, |t.y

  proc up =
    # setCursor ccNone
    winel.removeEventListener "mousemove", movMouse
    winel.removeEventListener "touchmove", moveTouch

  winel.addEventListener "mousemove", movMouse
  winel.addEventListener "touchmove", moveTouch

  winel.addEventListener "mouseup", up
  winel.addEventListener "touchend", up
  
proc registerHandleEvents =
  let el = ".extender-body".ql
  if el != nil:
    el.removeEventListener "mousedown", onPointerDown
    el.removeEventListener "touchstart", onPointerDown

    el.addEventlistener "mousedown", onPointerDown
    el.addEventlistener "touchstart", onPointerDown

proc createDom: VNode =
  registerHandleEvents()

  buildHtml tdiv:
    snackbar()

    tdiv(class = "w-100 h-screen-100 d-flex overflow-hidden"):
      let bsc = blocksStyleCtrl viewMode

      aside(id = "tw-side-bar",
        class = """d-flex flex-column 
                h-100 bg-dark p-1 overflow-y-auto overflow-x-hidden"""):

        sidebtn "fa-save", saveServer
        sidebtn "fa-plus", startInsertAtEnd
        sidebtn "fa-chevron-up", setInsertBefore
        sidebtn "fa-chevron-down", setInsertAfter
        sidebtn "fa-trash", deleteSelectedNodes
        sidebtn "fa-eye", changeViewMove
        sidebtn "fa-tag", noop
        sidebtn "fa-close", switchToTreeView

      tdiv(id = "editor-body", class = "d-flex " & bsc.wrapperCls):
        tdiv(id = settingsAreaId,
          class = "d-inline-block " & bsc.editorCls,
          style = style(bsc.cssProperty, fmt"{bsc.editorSize}px")):

          if app.state == asTreeView:
            tdiv(id = treeViewId,
              class = "overflow-y-scroll py-2 px-1 h-100 overflow-x-hidden"):

              recursiveList app.tree

          elif app.state == asSetting:
            tdiv(id = porpertySettingId,
                class = "mt-3 d-flex flex-column align-items-center justify-content-center p-2"):

              for s in app.focusedNode.settings():
                tdiv(class = "w-100"):
                  tdiv(class = "d-flex mx-2"):
                    italic(class = s.icon)
                    span(class = "mx-2"): text s.field
                  tdiv:
                    let
                      data = s.editorData()
                      editor = app.editors[data.name](data.input,
                          data.updateCallback)

                    editor

          elif app.state == asSelectComponent:
            tdiv(class = "d-flex flex-column h-100"):
              ul(class = "list-group rounded-0 overflow-y-scroll h-100"):

                if app.selected.len != 0:
                  li(class = """list-group-item d-flex justify-content-between align-items-center rounded-0
                      btn btn-outline-info mb-3 mt-1""",
                      onclick = moveSelectedNodes):
                    span: text "press X to paste marked nodes"
                    iconr "fa-paste"

                for i, c in app.filteredComponents:
                  li(class = """list-group-item d-flex justify-content-between align-items-center 
                    rounded-0 btn """ & iff(app.listIndex == i, "active"),
                    onclick = genSelectComponent(i)):
                    span: text c.name
                    italic(class = c.icon)

              tdiv:
                input(id = searchComponentInputId, `type` = "text",
                    class = "form-control w-100", autocomplete = "off"):
                  proc oninput(e: Event, v: VNode) =
                    app.listIndex = 0
                    app.filterString = e.target.value.toLower
                    # TODO here you should change
                    app.filteredComponents = app.availableComponents.filter(c =>
                        app.filterString in c.name.toLower.cstring)

        tdiv(id = extenderId, class = "extender btn btn-secondary border-1 p-0 d-inline-block " &
            bsc.extenderCls):

          let
            t =
              case viewMode
              of vmBothHorizontal: "x-translate-center my-2"
              of vmBothVertical: "y-translate-center mx-4"
              else: "d-none"

            icn =
              case viewMode
              of vmBothHorizontal: "fa-left-right"
              of vmBothVertical: "fa-up-down"
              else: ""

          tdiv(class = "extender-body d-flex rounded-circle justify-content-center align-items-center bg-primary " & t):
            icon icn

        tdiv(id = renderResultId,
          class = "tw-content overflow-y-scroll p-3 float-start d-inline-block " &
          bsc.contentCls,
          style = style(bsc.cssProperty, fmt"{bsc.contentSize}px")):

          verbatimElement editRootElementId


proc init* =
  register app, "raw-text-editor", rawTextEditor
  register app, "linear-text-editor", textInput
  register app, "file-upload-on-paste", fileLinkOrUploadOnPasteInput
  register app, "checkbox-editor", checkBoxEditor
  register app, "option-selector", selectEditor

  app.components = defaultComponents()
  regiterComponents app

  addEventListener window, "resize", proc =
    setSideBarSize sidebarWidth
    redraw()

  let root = instantiate(rootComponent, nil)
  root.data.hooks.dom = () => el editRootElementId
  resetApp root

  setRenderer createDom

  window.addEventListener "load", proc =
    fetchNote parseInt getWindowQueryParam "id"

  with document.documentElement:
    addEventListener "keydown", keyboardListener

when isMainModule: init()
