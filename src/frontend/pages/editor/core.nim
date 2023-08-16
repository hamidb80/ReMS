import std/[sets, tables, strutils, options, sugar, enumerate]
import std/[jsffi, dom]

import karax/[vdom]

import ../../../common/[datastructures]
import ../../utils/[browser, js]


type
  TwNode* = TreeNode[TwNodeData]
  Index* = int

  TwNodeData* = object
    visibleChildren*: bool ## to show in tree view
    component*: Component  ## the component that is instanciated from
    hooks*: Hooks          ## all the life cycle hooks and data retrival implemented lazy

  CallBack* = proc(data: JsObject)

  MountedBy* = enum
    mbUser         ## via interaction
    mbDeserializer ## via deserializer when restoring information

  TwNodeMode* = enum
    tmInteractive      ## for interaction
    tmOutputGeneration ## for serialization
    # tmDebug            ## for debug

  TwNodeStatusCode* = enum
    tsNothing
    tsLoading
    tsInfo
    tsSuccess
    tsWarning
    tsError

  TwNodeStatus = tuple[code: TwNodeStatusCode, msg: string]

  Hooks* = ref object
    dom*: proc(): Element                ## corresponding DOM element
    self*: proc(): TwNode                ## the node cotaining this
    role*: proc(child: Index): string    ## name of the node made by himself
    mark*: proc(child: Index)           

    status*: proc(): TwNodeStatus        ## internal status of the node e.g. error

    mounted*: proc(globalConfig: TwNode,
        by: MountedBy, mode: TwNodeMode) ## after creating and attaching to the parent
    die*: proc()                         ## before unmounts from DOM

    focus*: proc()                       ## when selected
    blur*: proc()                        ## when unselected
    hover*: proc()                       ## when mouse is over it
    unhover*: proc()                     ## when mouse leaves

    attachNode*: proc(n: TwNode, at: Index)
    detachNode*: proc(at: Index)

    capture*: proc(): JsObject           ## returns internal states
    restore*: proc(input: JsObject)      ## restores internal states
    refresh*: proc()                     ## refreshes, can be used before render called
    render*: proc()                      ## renders forcefully, used after restore

    acceptsAsChild*: proc(): seq[string] ## accepts what tags as child? use '*' for any
    settings*: proc(): seq[SettingsPart] ## settings page
    # options: proc(): seq[string] ## can add additional nodes?
    # actions: proc(): seq[string] ## can add additional nodes?

  SettingsPart* = object
    field*, icon*: string
    editorData*: proc(): EditorInitData

  EditorInitData* = object
    name*: string    ## component name of editor
    input*: JsObject ## initial input of editor
    updateCallback*: CallBack

  EditorInit* = proc(input: JsObject, updateCallback: CallBack): VNode

  Component* = ref object
    name*, icon*: string ## name of the component
    tags*: seq[string]   ## inline/media/<special component name>
    init*: proc(): Hooks ## creates new instance

## ---- syntax sugar
proc dom*(t: TwNode): auto = t.data.hooks.dom()
proc mounted*(t, globalConfig: TwNode, by: MountedBy,
    mode: TwNodeMode): auto = t.data.hooks.mounted(globalConfig, by, mode)
proc die*(t: TwNode) = t.data.hooks.die()
proc status*(t: TwNode): auto = t.data.hooks.status()
proc role*(t: TwNode, child: Index): auto = t.data.hooks.role(child)
proc mark*(t: TwNode, child: Index): auto = t.data.hooks.mark(child)
proc focus*(t: TwNode) = t.data.hooks.focus()
proc blur*(t: TwNode) = t.data.hooks.blur()
proc hover*(t: TwNode) = t.data.hooks.hover()
proc unhover*(t: TwNode) = t.data.hooks.unhover()
proc attachNode*(t, n: TwNode, i: Index) = t.data.hooks.attachNode(n, i)
proc detachNode*(t: TwNode, i: Index) = t.data.hooks.detachNode(i)
proc capture*(t: TwNode): auto = t.data.hooks.capture()
proc restore*(t: TwNode, input: JsObject) = t.data.hooks.restore(input)
proc refresh*(t: TwNode) = t.data.hooks.refresh()
proc render*(t: TwNode) = t.data.hooks.render()
proc acceptsAsChild*(t: TwNode): auto = t.data.hooks.acceptsAsChild()
proc settings*(t: TwNode): auto = t.data.hooks.settings()

proc firstChild*(t: TwNode, cname: string): TwNode =
  for ch in t.children:
    if ch.data.component.name == cname:
      return ch
  nil

proc serialize*(t: TwNode): JsObject =
  var children = newJsArray()
  for ch in t.children:
    children.add serialize ch

  <* {
    "name": t.data.component.name.cstring,
    "data": t.capture,
    "children": children}

proc instantiate*(c: Component): TwNode =
  var node = TwNode(data: TwNodeData(
    visibleChildren: true,
    component: c,
    hooks: c.init()))

  node.data.hooks.self = () => node
  node

proc attach*(father, child: TwNode, at: int) =
  child.father = father
  father.attachNode child, at

# ---------------------

type
  AppState* = enum
    asTreeView
    asSelectComponent
    asSetting

  InsertionMode* = enum
    imBefore
    imAfter
    imAppend

  App* = object
    version*: string
    state*: AppState

    editors*: Table[string, EditorInit]

    components*: Table[string, Component] ## components by name
    componentsByTags*: Table[string, seq[string]]

    tree*: TwNode                         ## tree of nodes from root
    selected*: HashSet[TreePath]          ## selected nodes
    focusedPath*: TreePath
    focusedNode*: TwNode

    availableComponents*, filteredComponents*: seq[Component]
    filterString*: cstring
    listIndex*: int                       ## used for keep tracking of selected component
    insertionMode*: InsertionMode


func register*(a: var App, name: string, e: EditorInit) =
  a.editors[name] = e

func register*(a: var App, c: Component, addToAll = true) =
  let cname = c.name.toLowerAscii

  a.components[cname] = c
  a.componentsByTags.add cname, cname

  if addToAll:
    a.componentsByTags.add "*", cname

  for t in c.tags:
    a.componentsByTags.add t, cname

func register*(a: var App, cs: openArray[Component]) =
  for c in cs:
    a.register c


proc serialize*(app: App): JsObject =
  <*{
    "version": app.version,
    "meta": {},
    "document": app.tree.serialize}

proc deserizalizeImpl*(
  app: App, root: Element,
  config: TwNode, j: JsObject
): TwNode =

  let cname = $j["name"].to(cstring)
  result = instantiate app.components[cname]

  if cname == "root":
    result.data.hooks.dom = () => root

  for i, ch in enumerate j["children"]:
    result.attach deserizalizeImpl(app, root, config, ch), i

  result.restore j["data"]
  result.mounted(config, mbDeserializer, tmInteractive)
  result.render()

proc deserizalize*(app: App, root: Element, j: JsObject): TwNode =
  deserizalizeImpl app, root, app.tree.firstChild "config", j["document"]
