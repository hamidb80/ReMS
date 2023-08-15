import std/[sequtils, cstrutils, strutils, sets, with, strformat, sugar, tables]
import std/[dom, jsconsole]

import karax/[karax, karaxdsl, vdom]
import caster

import ./[core, components, editors]
import ../../../common/conventions
import ../../utils/[js, browser]


var app = App(state: asTreeView)

app.register rootComponent, false
app.register configComponent, false
app.register tableRowComponent, false
app.register [
  rawTextComponent,
  paragraphComponent,
  linkComponent,
  boldComponent,
  italicComponent,
  strikethroughComponent,
  h1Component,
  h2Component,
  h3Component,
  h4Component,
  h5Component,
  h6Component,
  latexComponent,
  mdComponent,
  verticalSpaceComponent,
  imageComponent,
  videoComponent,
  listComponent,
  tableComponent,
  customHtmlComponent]

app.register "raw-text-editor", rawTextEditor
app.register "linear-text-editor", textInput
app.register "checkbox-editor", checkBoxEditor
app.register "option-selector", selectEditor

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
        if node.isLeaf:
          "bi bi-asterisk"
        elif node.data.visibleChildren:
          "bi bi-caret-down-fill"
        else:
          "bi bi-caret-right-fill"):

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

template iff(cond, value): untyped =
  if cond: value
  else: default typeof value

const
  treeViewId = "tw-tree-view"
  porpertySettingId = "tw-property-setting"
  sidebarId = "tw-side-bar"
  editRootElementId = "tw-editor-root-element"
  searchComponentInputId = "tw-search-component-input"

proc editPage: VNode =
  buildHtml tdiv(class = "d-flex flex-row-reverse justify-content-between h-100 w-100"):
    tdiv(id = "tw-render", class="tw-content h-100 overflow-y-scroll"):
      verbatim fmt"<div id='{editRootElementId}'></div>"

    aside(id = sidebarId, class="overflow-hidden"):
      if app.state == asTreeView:
        tdiv(id = treeViewId, class="overflow-y-scroll h-100"):
          recursiveList app.tree

      elif app.state == asSetting:
        tdiv(id = porpertySettingId, class = "mt-3 d-flex flex-column align-items-center justify-content-center"):
          for s in app.focusedNode.settings():
            tdiv:
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
            input(id=searchComponentInputId, `type`="text", class="form-control w-100"):
              proc oninput(e: Event, v: VNode) = 
                app.listIndex = 0
                app.filterString = e.target.value.toLower
                app.filteredComponents = app.availableComponents.filter(c => c.name.toLower.startsWith app.filterString)

proc resetApp(root: TwNode) = 
  app.tree = root
  app.focusedNode = root
  app.focusedPath = @[]

# ----- Events ------------------------------

proc prepareComponentSelection(parentNode: TwNode) = 
  reset app.availableComponents
  reset app.listIndex

  var acc = initHashSet[string]()
  for t in parentNode.acceptsAsChild:
    for cname in app.componentsByTags[t]:
      acc.incl cname

  for cname in acc:
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
        app.focusedPath.add 0
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

        n.die 
        f.detachNode i
        app.focusedNode = f
      
    of "t":
      negate app.focusedNode.data.visibleChildren

    of "q":
      ## to query children of focued node like XPath like VIM editor
    
    of "y":
      ## go to the last pathTree state

    of "a":
      ## show actions of focused element
    
    of "s":
      downloadFile "data.json", "application/json", stringify serialize app

    of "h": 
      let el = createElement("div", {"class": "tw-content"})
      downloadFile "data.html", "text/html", deserizalize(app, el, serialize app).dom.innerHTML
      
    of "c":
      ## cut

    of "p":
      ## cut

    of "u":
      ## undo

    of "o":
      selectFile proc(c: cstring) = 
        purge app.tree.dom
        resetApp deserizalize(app, app.tree.dom, c.parseJs)
        redraw()

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
          document.activeElement.blur()
    
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
      var newNode = instantiate(app.filteredComponents[app.listIndex])
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

      newNode.mounted(nil, mbUser, tmInteractive)
      app.focusedNode = newNode
      app.state = asTreeView

    else:
      discard

  redraw()

  if lastFocus != app.focusedNode:
    lastFocus.blur
    app.focusedNode.focus

    let
      t = document.getElementById pathId app.focusedPath
      w = document.getElementById treeViewId

    w.scrollTop = t.offsetTop - 160

  ## TODO shortcuts ----
  # folding shortcuts 
  ## Toggle input/textarea
  ## Toggle input/textarea
  ## Toggle rtl/ltr

# ----- Init ------------------------------


# TODO Pinterest layout
# TODO use kraut for routing
# TODO save document title, link, tags, decription, ... in root config
proc homePage: VNode =
  buildHtml tdiv(class = ""):
    discard


when isMainModule:
  let root = instantiate rootComponent
  root.data.hooks.dom = () => el editRootElementId
  resetApp root
  
  setRenderer editPage
  # setRenderer homePage

  with document.documentElement:
    addEventListener "keydown", keyboardListener