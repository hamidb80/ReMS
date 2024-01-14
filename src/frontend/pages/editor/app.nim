import std/[sequtils, strutils, sets, with, strformat, sugar, tables, math]
import std/[dom, jsffi]

import karax/[karax, karaxdsl, vdom, vstyles]
import questionable, caster

import ../../../backend/database/[models]
import ./[core, components, inputs]
import ../../utils/[js, browser, api, ui]
import ../../components/[snackbar]
import ../../../common/[conventions, datastructures, types, iter]


type
  ViewMode = enum
    vmBoth
    vmEditor
    vmPreview


var
  app = App(state: asTreeView)
  sidebarWidth = 300
  viewmode = vmBoth


register app, "raw-text-editor", rawTextEditor
register app, "linear-text-editor", textInput
register app, "file-upload-on-paste", fileLinkOrUploadOnPasteInput
register app, "checkbox-editor", checkBoxEditor
register app, "option-selector", selectEditor


app.components = defaultComponents()
regiterComponents app

# TODO app ability to copy node path
# TODO ability to add/remove tags here
# TODO import to a specific node not replace the whole tree!

# ----- UI ------------------------------

proc setSidebarWidth(w: int) =
  sidebarWidth = clamp(w, 100 .. window.innerWidth - 200)

addEventListener window, "resize", proc =
  setSidebarWidth sidebarWidth
  redraw()

proc saveServer =
  let id = parseInt getWindowQueryParam "id"
  apiUpdateNoteContent id, serialize app, proc =
    notify "note updated!"

func cls(path, hover: TreePath, selected: HashSet[TreePath],
    active: string): string =
  if path == hover: active
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


    h6(class = "badge text-start px-2 w-100 " & cls(path, hover, selected, c)):
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

        span(class = "me-2 " & iff(path == hover, "", t)):
          if s.code != tsNothing:
            text s.msg
            italic(class = i & " mx-1")

          elif not isRoot node:
            text node.father.role path[^1]

        let p = path
        proc onclick =
          app.focusedPath = p
          app.focusedNode = node
          redraw()

        proc ondblclick =
          app.state = asSetting

    if node.data.visibleChildren:
      for i, n in node.children:
        (path.add i)
        tdiv(class = "branch ms-4"):
          recursiveListImpl n, path, hover, selected
        (path.npop)

proc recursiveList(data: TwNode): VNode =
  var treepath = newSeq[int]()
  recursiveListImpl data, treepath, app.focusedPath, app.selected

const
  treeViewId = "tw-tree-view"
  porpertySettingId = "tw-property-setting"
  settingsAreaId = "tw-settings-area"
  extenderId = "tw-extender"
  editRootElementId = "tw-editor-root-element"
  searchComponentInputId = "tw-search-component-input"

proc resetApp(root: TwNode) =
  app.tree = root
  app.focusedNode = root
  app.focusedPath = @[]


type BlockStyles = tuple
  editorCls: cstring
  editorWidth: int

  contentCls: cstring
  contentWidth: int

proc blocksStyleCtrl(viewmode: ViewMode): BlockStyles =
  case viewmode
  of vmBoth: ("", sidebarWidth, "", window.innerWidth - sidebarwidth)
  of vmEditor: ("", window.innerWidth, "d-none", 0)
  of vmPreview: ("d-none", 50, "", window.innerWidth)

# ----- Events ------------------------------

proc prepareComponentSelection(parentNode: TwNode) =
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
  app.insertionMode = imAppend
  prepareComponentSelection app.focusedNode

proc startInsertBefore =
  setState asSelectComponent
  app.insertionMode = imBefore
  prepareComponentSelection app.focusedNode.father

proc startInsertAfter =
  setState asSelectComponent
  app.insertionMode = imAfter
  prepareComponentSelection app.focusedNode.father

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

proc deleteSelectedNode =
  if not isRoot app.focusedNode:
    let
      n = app.focusedNode
      i = app.focusedPath.pop
      f = n.father

    die n
    detachNode f, i
    app.focusedNode = f

proc moveToUp =
  if app.focusedPath.len > 0:
    if app.focusedPath[^1] == 0:
      discard
    else:
      dec app.focusedPath[^1]
      app.focusedNode = app.focusedNode.father.children[app.focusedPath[^1]]


proc moveToDown =
  if app.focusedPath.len > 0:
    if app.focusedPath[^1] + 1 == app.focusedNode.father.children.len:
      discard
    else:
      app.focusedPath[^1].inc
      app.focusedNode = app.focusedNode.father.children[app.focusedPath[^1]]


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

    of kcArrowLeft: # goes inside
      if app.focusedPath.len > 0:
        app.focusedPath.npop
        app.focusedNode = app.focusedNode.father

    of kcArrowRight: # goes outside
      if app.focusedNode.isLeaf or not app.focusedNode.data.visibleChildren:
        discard
      else:
        add app.focusedPath, 0
        app.focusedNode = app.focusedNode.children[0]

    of kcPageDown: # 10 more down
      discard

    of kcPageUp: # 10 more up
      discard

    of kcHome:
      discard

    of kcEnd:
      discard

    of kcn: # insert inside
      startInsertAtEnd()

    of kcOpenbracket: # insert before
      startInsertBefore()

    of kcCloseBraket: # insert after
      startInsertAfter()

    of kcDelete: # delete node
      deleteSelectedNode()

    of kcT: negate app.focusedNode.data.visibleChildren

    of kcQ: # to query children of focued node like XPath like VIM editor
      discard

    of kcY: # go to the last pathTree state
      discard

    of kcM: # mark
      discard

    of kcA: # show actions of focused element
      discard

    of kcK: # download as JSON
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

    of kcC: # cut
      discard

    of kcP: # cut
      discard

    of kcU: # undo
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

    of kcR: # redo
      discard

    of kcEnter:
      if app.state == asTreeView:
        app.state = asSetting

    else: discard

  of asSetting:

    case e.keyCode.KeyCode
    of kcEscape:
      if app.state == asSetting:
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

# FIXME add a API module to handle all these dirty codes ..., and also to not repeat yourself
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
    echo "whaaat", getcurrentExceptionmsg()

proc genSelectComponent(i: int): proc() =
  proc =
    createInstance i

proc createDom: VNode =
  buildHtml tdiv:
    snackbar()

    tdiv(class = "w-100 h-screen-100 d-flex overflow-hidden"):
      let bsc = blocksStyleCtrl viewmode

      tdiv(id = "left-container",
        class = "float-start h-100 d-flex flex-row mw-100",
        style = style(StyleAttr.width, fmt"{bsc.editorWidth}px")):

        aside(id = "tw-side-bar",
          class = "h-100 bg-dark justify-contnent-center p-1 overflow-y-auto overflow-x-hidden"):

          button(class = "btn btn-outline-primary my-1 rounded px-2 py-3"):
            icon "fa-save fa-xl"
            proc onclick =
              saveServer()

          button(class = "btn btn-outline-primary my-1 rounded px-2 py-3"):
            icon "fa-plus fa-xl"
            proc onclick =
              startInsertAtEnd()

          button(class = "btn btn-outline-primary my-1 rounded px-2 py-3"):
            icon "fa-chevron-up fa-xl"
            proc onclick =
              startInsertBefore()

          button(class = "btn btn-outline-primary my-1 rounded px-2 py-3"):
            icon "fa-chevron-down fa-xl"
            proc onclick =
              startInsertAfter()

          button(class = "btn btn-outline-primary my-1 rounded px-2 py-3"):
            icon "fa-trash fa-xl"
            proc onclick =
              deleteSelectedNode()

          button(class = "btn btn-outline-primary my-1 rounded px-2 py-3"):
            icon "fa-eye fa-xl"

            proc onclick =
              incRound viewMode

          button(class = "btn btn-outline-primary my-1 rounded px-2 py-3"):
            icon "fa-tag fa-xl"

          button(class = "btn btn-outline-primary my-1 rounded px-2 py-3"):
            icon "fa-close fa-xl"

            proc onclick =
              app.state = asTreeView

        tdiv(id = settingsAreaId, 
          class = "overflow-hidden d-inline-block w-100 " & bsc.editorCls):

          if app.state == asTreeView:
            tdiv(id = treeViewId, 
              class = "overflow-y-scroll py-2 px-1 h-100"):

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
                for i, c in app.filteredComponents:
                  li(class = "list-group-item d-flex justify-content-between align-items-center btn btn-white rounded-0 " &
                      iff(app.listIndex == i, "active"),
                      onclick = genSelectComponent(i)):
                    span: text c.name
                    italic(class = c.icon)

              tdiv:
                input(id = searchComponentInputId, `type` = "text",
                    class = "form-control w-100", autocomplete = "off"):
                  proc oninput(e: Event, v: VNode) =
                    app.listIndex = 0
                    app.filterString = e.target.value.toLower
                    app.filteredComponents = app.availableComponents.filter(c =>
                        app.filterString in c.name.toLower.cstring)

        tdiv(id = extenderId, class = "extender h-100 btn btn-secondary border-1 p-0 d-inline-block"):
          proc onMouseDown =
            # setCursor ccresizex

            winel.onmousemove = proc(e: Event as MouseEvent) {.caster.} =
              setSidebarWidth e.x
              redraw()

            winel.onmouseup = proc(e: Event) =
              # setCursor ccNone
              reset winel.onmousemove
              reset winel.onmouseup

      tdiv(id = "tw-render", 
        class = "tw-content h-100 overflow-y-scroll p-3 float-start d-inline-block " & bsc.contentCls,
        style = style(StyleAttr.width, fmt"""{bsc.contentWidth}px""")):
        verbatim fmt"<div id='{editRootElementId}'></div>"

proc init* =
  let root = instantiate(rootComponent, nil)
  root.data.hooks.dom = () => el editRootElementId
  resetApp root

  setRenderer createDom
  settimeout 500, proc =
    fetchNote parseInt getWindowQueryParam "id"

  with document.documentElement:
    addEventListener "keydown", keyboardListener

when isMainModule: init()
