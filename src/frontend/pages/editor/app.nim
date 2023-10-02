import std/[sequtils, cstrutils, strutils, sets, with, strformat, sugar, tables, math]
import std/[dom, jsconsole, jsffi]

import karax/[karax, karaxdsl, vdom, vstyles]
import questionable, caster

import ../../../backend/routes
import ../../../backend/database/[models]
import ./[core, components, inputs]
import ../../utils/[js, browser, api, ui]
import ../../components/[snackbar]
import ../../../common/[conventions, datastructures, types]


var 
  app = App(state: asTreeView)
  sidebarWidth = 300

app.register "raw-text-editor", rawTextEditor
app.register "linear-text-editor", textInput
app.register "checkbox-editor", checkBoxEditor
app.register "option-selector", selectEditor

app.components = defaultComponents()
app.regiterComponents

# TODO add side bar on the left for more options like save, load from disk, ...

# ----- UI ------------------------------

func cls(path, hover: TreePath, selected: HashSet[TreePath], active: string): string =
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

  buildHtml tdiv(id = pathId path, class="tw-pointer"):
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
    

    h6(class = "badge text-start w-100 " & cls(path, hover, selected, c)):
      proc onMouseEnter = node.hover()
      proc onMouseLeave = node.unhover()

      italic(class =
        if node.isLeaf: "bi bi-asterisk"
        elif node.data.visibleChildren: "bi bi-caret-down-fill"
        else: "bi bi-caret-right-fill"):

        proc onclick = 
          negate node.data.visibleChildren
          redraw()

      tdiv(class="d-inline-flex w-100 justify-content-between"):
        span:
          italic(class = "mx-2 " & node.data.component.icon)
          span: text node.data.component.name

        span(class = "me-1 " & iff(path == hover, "", t)):
          if s.code != tsNothing:
            italic(class = i & " mx-1")
            text s.msg
            
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

proc createDom: VNode =
  buildHtml tdiv:
    snackbar()

    tdiv(class = "h-100 w-100"):
      tdiv(id="left-container"):
        aside(id="tw-side-bar", class="h-100 bg-dark d-flex justify-contnent-center flex-column flex-wrap p-1 float-start "):
          button(class="btn btn-outline-primary my-1 rounded px-2 py-3"):
            icon "fa-solid fa-save fa-xl"
          
          button(class="btn btn-outline-primary my-1 rounded px-2 py-3"):
            icon "fa-solid fa-tag fa-xl"

          button(class="btn btn-outline-primary my-1 rounded px-2 py-3"):
            icon "fa-solid fa-close fa-xl"

        tdiv(id = settingsAreaId, class="overflow-hidden float-start d-inline-block", 
          style = style(StyleAttr.width, fmt"{sidebarWidth}px")):
          if app.state == asTreeView:
            tdiv(id = treeViewId, class="overflow-y-scroll h-100"):
              recursiveList app.tree

          elif app.state == asSetting:
            tdiv(id = porpertySettingId, class = "mt-3 d-flex flex-column align-items-center justify-content-center p-2"):
              for s in app.focusedNode.settings():
                tdiv(class="w-100"):
                  tdiv(class="d-flex mx-2"):
                    italic(class= s.icon)
                    span(class="mx-2"): text s.field
                  tdiv:
                    let 
                      data = s.editorData()
                      editor = app.editors[data.name](data.input, data.updateCallback)

                    editor

          elif app.state == asSelectComponent:
            tdiv(class="d-flex flex-column h-100"):
              ul(class="list-group rounded-0 overflow-y-scroll h-100"):
                for i, c in app.filteredComponents:
                  li(class="list-group-item d-flex justify-content-between align-items-center " & iff(app.listIndex == i, "active")):
                    span: text c.name
                    italic(class = c.icon)

              tdiv:
                input(id=searchComponentInputId, `type`="text", class="form-control w-100", autocomplete="off"):
                  proc oninput(e: Event, v: VNode) = 
                    app.listIndex = 0
                    app.filterString = e.target.value.toLower
                    app.filteredComponents = app.availableComponents.filter(c => c.name.toLower.startsWith app.filterString)

        tdiv(id = extenderId, class="extender h-100 btn btn-secondary border-1 p-0 float-start d-inline-block"):
          proc onMouseDown =
            # setCursor ccresizex

            winel.onmousemove = proc(e: Event as MouseEvent) {.caster.} =
              sidebarWidth = clamp(e.x - el(settingsAreaId).offsetLeft, 10 .. window.innerWidth - 300)
              redraw()

            winel.onmouseup = proc(e: Event) =
              # setCursor ccNone
              reset winel.onmousemove
              reset winel.onmouseup
              
      tdiv(id = "tw-render", class="tw-content h-100 overflow-y-scroll p-3 d-inline-block",
          style = style(StyleAttr.width, fmt"""{window.innerWidth - sidebarwidth - 60}px""")):
        verbatim fmt"<div id='{editRootElementId}'></div>"


proc resetApp(root: TwNode) = 
  app.tree = root
  app.focusedNode = root
  app.focusedPath = @[]

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

proc keyboardListener(e: Event as KeyboardEvent) {.caster.} =
  let lastFocus = app.focusedNode

  case app.state
  of asTreeView:
    case $e.key
    of "ArrowUp":
      e.preventDefault

      if app.focusedPath.len > 0:
        if app.focusedPath[^1] == 0:
          discard
        else:
          dec app.focusedPath[^1]
          app.focusedNode = app.focusedNode.father.children[app.focusedPath[^1]]

    of "ArrowDown":
      e.preventDefault

      if app.focusedPath.len > 0:
        if app.focusedPath[^1] + 1 == app.focusedNode.father.children.len:
          discard
        else:
          app.focusedPath[^1].inc
          app.focusedNode = app.focusedNode.father.children[app.focusedPath[^1]]

    of "ArrowLeft":
      if app.focusedPath.len > 0:
        app.focusedPath.npop
        app.focusedNode = app.focusedNode.father

    of "ArrowRight":
      if app.focusedNode.isLeaf or not app.focusedNode.data.visibleChildren:
        discard
      else:
        add app.focusedPath, 0
        app.focusedNode = app.focusedNode.children[0]

    of "PageDown":
      ## 10 more down

    of "PageUp":
      ## 10 more up

    of "Home": discard
    
    of "End": discard

    of "n":
      setState asSelectComponent
      app.insertionMode = imAppend
      prepareComponentSelection app.focusedNode

    of "[": 
      setState asSelectComponent
      app.insertionMode = imBefore
      prepareComponentSelection app.focusedNode.father
      
    of "]": 
      setState asSelectComponent
      app.insertionMode = imAfter
      prepareComponentSelection app.focusedNode.father

    of "Delete": 
      if not isRoot app.focusedNode:
        let 
          n = app.focusedNode
          i = app.focusedPath.pop
          f = n.father

        die n 
        detachNode f, i
        app.focusedNode = f
      
    of "t":
      negate app.focusedNode.data.visibleChildren

    of "q":
      ## to query children of focued node like XPath like VIM editor
    
    of "y":
      ## go to the last pathTree state
    
    of "m": # mark
      discard

    of "a":
      ## show actions of focused element
    
    of "k":
      downloadFile "data.json", "application/json", stringify forceJsObject serialize app
    
    of "s":
      let id = parseInt getWindowQueryParam("id")
      apiUpdateNoteContent id, serialize app, proc = 
        notify "note updated!"

    of "h": 
      proc afterLoad(t: TwNode) = 
        downloadFile "data.html", "text/html", t.dom.innerHTML

      # take a copy
      deserizalize(app.components, serialize app)
      .dthen(afterLoad)

    of "c":
      ## cut

    of "p":
      ## cut

    of "u":
      ## undo

    of "o":
      selectFile proc(c: cstring) = 
        purge app.tree.dom
        
        proc done(t: TwNode) = 
          resetApp t
          redraw()

        let data = cast[TreeNodeRaw[JsObject]](c.parseJs)
        deserizalize(app.components, data, some app.tree.dom)
        .then(done)
        .dcatch () => notify "could not load the file"

    of "r":
      ## redo

    of "Enter":
      if app.state == asTreeView:
        app.state = asSetting

    else: discard

  of asSetting:

    case $e.key
    of "Escape": 
      if app.state == asSetting:
        if document.activeElement == document.body:
            app.state = asTreeView
        else:
          blur document.activeElement

    else: discard

  of asSelectComponent:
    case $e.key
    of "ArrowLeft", "ArrowRight":
      e.preventDefault

    of "ArrowUp":
      app.listIndex = max(0, app.listIndex-1)
  
    of "ArrowDown":
      app.listIndex = min(app.availableComponents.high, app.listIndex+1)

    of "Escape":
      app.state = asTreeView
      
    of "Enter":
      var newNode = instantiate(app.filteredComponents[app.listIndex], app.components)
      
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

template after(time, action): untyped = 
  setTimeout time, () => action

template fn(body): untyped = 
  proc = 
    body

# FIXME add a API module to handle all these dirty codes ..., and also to not repeat yourself
proc fetchNote(id: Id) = 
  apiGetNote id, proc(n: NoteItemView) = 
    deserizalize(app.components, n.data, some app.tree.dom, wait = false)
    .then(resetApp)
    .then(fn after(100, redraw()))
    .dcatch proc = 
      notify "failed to fetch note data"

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
