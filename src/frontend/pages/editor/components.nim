import std/[jsffi, dom, asyncjs, jsconsole]
import std/[with, options, sequtils, tables, sugar]

import ./core
import ../../utils/[browser, js, api]
import ../../jslib/[katex, marked, axios]
import ../../../common/[conventions, types, datastructures]
import ../../../backend/[routes]
import ../../../backend/database/[models]


# ----- Utils -----------

const
  twFocusClass = "tw-focus-hover"
  twHoverClass = "tw-mouse-hover"
  displayInlineClass = "d-inline"

template errProc(returnType, msg): untyped =
  proc(): returnType =
    raise newException(ValueError, msg)

template defHooks(body): untyped {.dirty.} =
  when not compiles hooks:
    result = Hooks()
    var hooks = result

  with hooks: # defaults
    dom = errProc(Element, "hooks.dom() is not set yet")
    status = () => (tsNothing, "")
    role = (i: Index) => ""
    mark = proc(i: Index) = discard
    die = noop
    focus = addFocusClass hooks
    blur = removeFocusClass hooks
    hover = addHoverClass hooks
    unhover = removeHoverClass hooks
    capture = returnNull
    restore = nothingToRestore
    mounted = genMounted: discard
    render = genRender: discard
    refresh = noop
    settings = noSettings

    attachNode = proc(child: TwNode, at: Index) =
      attachNodeDefault hooks.self(), child, hooks.dom(), child.dom(), at

    detachNode = proc(at: Index) =
      dettachNodeDefault hooks.self(), at, false

  with hooks: # custom
    body

  result = hooks

template defComponent(ident, identstr, icone, tagss, initproc): untyped =
  let ident* = Component(
    name: identstr,
    icon: icone,
    tags: tagss,
    init: initproc)

# ----- Defaults -----------

func genAllowedTags(tags: seq[cstring]): () -> seq[cstring] =
  () => tags

let
  noTags = genAllowedTags @[]
  anyTag = genAllowedTags @[c"global"]
  onlyInlines = genAllowedTags @[c"inline"]

func noSettings: seq[SettingsPart] = @[]

func returnNull: JsObject = nil

func nothingToRestore(input: JsObject) = discard

proc addFocusClass(hooks: Hooks): proc() =
  proc =
    hooks.dom().classList.add twFocusClass

proc removeFocusClass(hooks: Hooks): proc() =
  proc =
    hooks.dom().classList.remove twFocusClass

proc addHoverClass(hooks: Hooks): proc() =
  proc =
    hooks.dom().classList.add twHoverClass

proc removeHoverClass(hooks: Hooks): proc() =
  proc =
    hooks.dom().classList.remove twHoverClass

proc attachNodeDefault(father, child: TwNode, wrapper, what: Element, at: Index) =
  if father.children.len == at:
    father.children.add child
    wrapper.appendChild what
  elif 0 == at:
    father.children.insert child, at
    wrapper.prepend what
  else: # 1..children.high
    father.children.insert child, at
    wrapper.children[at-1].after what

proc dettachNodeDefault(self: TwNode, at: Index, basedOnDom: bool) =
  remove:
    if basedOnDom: self.dom.childNodes[at]
    else: self.children[at].dom

  self.children.delete at

proc genState[T](init: T): tuple[getter: () -> T, setter: T -> void] =
  let value = new T
  value[] = init
  result.getter = () => value[]
  result.setter = (t: T) => value[].set t

template mutState(setter, datatype): untyped {.dirty.} =
  proc (data: JsObject) =
    hooks.refresh()
    setter data.to datatype
    discard hooks.render()

template genMounted(body): untyped {.dirty.} =
  proc(by: MountedBy, mode: TwNodeMode) =
    body

template genRender(body): untyped {.dirty.} =
  proc(): options.Option[Future[void]] =
    body

# ----- Definition -----------

proc initRoot: Hooks =
  defHooks:
    dom = errProc(Element, "this hooks should be set by app manually")
    hover = noop
    unhover = noop
    focus = noop
    blur = noop
    acceptsAsChild = genAllowedTags @[c"block", c"config"]

proc initRawText: Hooks =
  let
    el = createElement "span"
    (content, cSet) = genState c""
    (spaceAround, spSet) = genState true

  defHooks:
    dom = () => el
    acceptsAsChild = noTags

    capture = () => <*{
      "content": content(),
      "spaceAround": spaceAround()}

    restore = proc(input: JsObject) =
      cSet input["content"].to cstring
      spSet input["spaceAround"].to bool

    render = genRender:
      el.innerText =
        if spaceAround(): c" " & content() & c" "
        else: content()

    settings = () => @[
      SettingsPart(
        field: "content",
        icon: "bi bi-type",
        editorData: () => EditorInitData(
          name: "raw-text-editor",
          input: content().toJs,
          updateCallback: mutState(cset, cstring))),

      SettingsPart(
        field: "space around",
        icon: "bi bi-backspace-fill",
        editorData: () => EditorInitData(
          name: "checkbox-editor",
          input: spaceAround().toJs,
          updateCallback: mutState(spSet, bool)))]

proc attachInstance(comp: Component, hooks: Hooks, ct: ComponentsTable) =
  let n = instantiate(comp, ct)
  hooks.self().attach n, 0
  n.mounted mbUser, tmInteractive


proc wrapperTextElement(tag: string): () -> Hooks =
  proc: Hooks =
    let el = createElement tag
    defHooks:
      dom = () => el
      acceptsAsChild = onlyInlines
      mounted = genMounted:
        if mode == tmInteractive and by == mbUser:
          let ct = hooks.componentsTable()
          attachInstance ct["raw-text"], hooks, ct

let
  initBold = wrapperTextElement "b"
  initItalic = wrapperTextElement "i"
  initUnderline = wrapperTextElement "u"
  initStrikethrough = wrapperTextElement "s"
  initTitleH1 = wrapperTextElement "h1"
  initTitleH2 = wrapperTextElement "h2"
  initTitleH3 = wrapperTextElement "h3"
  initTitleH4 = wrapperTextElement "h4"
  initTitleH5 = wrapperTextElement "h5"
  initTitleH6 = wrapperTextElement "h6"


proc initParagraph: Hooks =
  let
    el = createElement("span", {"class": "tw-paragraph"})
    (dir, setDir) = genState c"auto"

  defHooks:
    dom = () => el
    acceptsAsChild = onlyInlines
    capture = () => tojs dir()
    restore = (j: JsObject) => setDir j.to cstring
    render = genRender:
      console.log "Hey", dir()
      case $dir()
      of "auto": el.setAttr "dir", "auto"
      of "ltr": el.setAttr "dir", "ltr"
      of "rtl": el.setAttr "dir", "rtl"
      else: discard
      console.log "Bye", dir()

    mounted = genMounted:
      # XXX hooks.render()
      if mode == tmInteractive and by == mbUser:
        let ct = hooks.componentsTable()
        attachInstance ct["raw-text"], hooks, ct

    settings = () => @[
      SettingsPart(
        field: "text direction",
        icon: "bi bi-signpost-fill",
        editorData: () => EditorInitData(
          name: "option-selector",
          input: <* {
            "default": dir(),
            "data": [
              ["auto", "auto"],
              ["ltr", "ltr"],
              ["rtl", "rtl"]]},
          updateCallback: mutState(setDir, cstring)))]

proc initVerticalSpace: Hooks =
  let el = createElement("hr", {"class": "tw-vertical-space"})

  defHooks:
    dom = () => el
    acceptsAsChild = noTags

proc initLink: Hooks =
  let
    el = createElement "a"
    (url, setUrl) = genState c""

  defHooks:
    dom = () => el
    acceptsAsChild = onlyInlines
    capture = () => tojs url()
    restore = (j: JsObject) => setUrl(j.to cstring)
    render = genRender:
      el.setAttr("href", url())

    mounted = genMounted:
      el.setAttr "target", "_blank"

      if mode == tmInteractive and by == mbUser:
        attachInstance hooks.componentsTable()["raw-text"], hooks,
            hooks.componentsTable()

    settings = () => @[
      SettingsPart(
        field: "link",
        icon: "bi bi-link-45deg",
        editorData: () => EditorInitData(
          name: "raw-text-editor",
          input: toJs url(),
          updateCallback: mutState(setUrl, cstring)))]


proc initLatex: Hooks =
  let
    el = createElement("div", {"class": "tw-latex"})
    (content, cset) = genState c""
    (inline, iset) = genState false

  defHooks:
    dom = () => el
    acceptsAsChild = noTags
    capture = () => <*{
      "content": content(),
      "inline": inline()}

    restore = proc(input: JsObject) =
      cset input["content"].to cstring
      iset input["inline"].to bool

    render = genRender:
      el.ctrlClass displayInlineClass, inline()
      el.innerHTML = latexToHtml(content(), inline())

    settings = () => @[
      SettingsPart(
        field: "latex code",
        icon: "bi bi-regex",
        editorData: () => EditorInitData(
          name: "raw-text-editor",
          input: toJs content(),
          updateCallback: mutState(cset, cstring))),

      SettingsPart(
        field: "inline",
        icon: "bi bi-displayport",
        editorData: () => EditorInitData(
          name: "checkbox-editor",
          input: toJs inline(),
          updateCallback: mutState(iset, bool)))]


proc initImage: Hooks =
  let
    hooks = Hooks()
    wrapper = createElement("figure", {"class": "tw-image-wrapper"})
    img = createElement "img"
    caption = createElement "figcaption"
    (url, setUrl) = genState c""
    (width, setWidth) = genState c""
    (height, setHeight) = genState c""
    (status, setStatus) = genState (tsWarning, "no url")

  img.onerror = proc(e: Event) =
    setStatus (tsError, "failed to load")

  img.onload = proc(e: Event) =
    setStatus (tsNothing, "")

  defHooks:
    dom = () => wrapper
    acceptsAsChild = proc: seq[cstring] =
      if hooks.self().children.len == 0: @[c"paragraph"]
      else: @[]

    capture = () => <* {
      "url": url(),
      "width": width(),
      "height": height()}

    restore = proc(j: JsObject) =
      setUrl j["url"].to cstring
      setWidth j["width"].to cstring
      setHeight j["height"].to cstring

    role = (i: Index) => "caption"
    status = () => status()

    render = genRender:
      img.setAttr "src", url()
      img.setAttr "style", toInlineCss {"max-width": width(),
          "max-height": height()}

    mounted = genMounted:
      wrapper.append img, caption
      if mode == tmInteractive and by == mbUser:
        attachInstance hooks.componentsTable()["paragraph"], hooks,
            hooks.componentsTable()

    attachNode = proc(child: TwNode, at: Index) =
      attachNodeDefault hooks.self(), child, caption, child.dom, at

    settings = () => @[
      SettingsPart(
        field: "url",
        icon: "bi bi-link-45deg",
        editorData: () => EditorInitData(
          name: "raw-text-editor",
          input: toJs url(),
          updateCallback: mutState(setUrl, cstring))),

      SettingsPart(
        field: "width",
        icon: "bi bi-arrow-right",
        editorData: () => EditorInitData(
          name: "linear-text-editor",
          input: toJs width(),
          updateCallback: mutState(setWidth, cstring))),

      SettingsPart(
        field: "height",
        icon: "bi bi-arrow-down",
        editorData: () => EditorInitData(
          name: "linear-text-editor",
          input: toJs height(),
          updateCallback: mutState(setHeight, cstring)))]

proc initVideo: Hooks =
  let
    el = createElement "video"
    (url, setUrl) = genstate c""

  defHooks:
    dom = () => el
    acceptsAsChild = noTags
    capture = () => tojs url()
    restore = (j: JsObject) => setUrl j.to cstring
    render = genRender:
      el.setAttr("src", url())

    mounted = genMounted:
      el.setAttr "controls", ""

    settings = () => @[
      SettingsPart(
        field: "url",
        icon: "bi bi-link-45deg",
        editorData: () => EditorInitData(
          name: "raw-text-editor",
          input: toJs url(),
          updateCallback: mutState(setUrl, cstring)))]

# TODO make restore hook to get values optionally

proc initList: Hooks =
  let
    ul = createElement "ui"
    (style, setStyle) = genState c""

  defHooks:
    dom = () => ul
    acceptsAsChild = anyTag

    # capture = () => tojs url()
    # restore = (j: JsObject) => setUrl(j.to cstring)

    refresh = proc =
      ul.class = "content-list"

    render = genRender:
      let c =
        case $style()
        of "persian": "list-persian-number"
        of "roman": "list-roman"
        of "latin": "list-latin"
        of "decimal": "list-decimal"
        else: "list-disc"

      ul.classList.add c

    mounted = genMounted:
      hooks.refresh()

    attachNode = proc(child: TwNode, at: Index) =
      let li = createElement "li"
      li.appendChild child.dom
      attachNodeDefault hooks.self(), child, hooks.dom(), li, at

    detachNode = proc(at: Index) =
      dettachNodeDefault hooks.self(), at, true

    settings = () => @[
      SettingsPart(
        field: "text direction",
        icon: "bi bi-signpost-fill",
        editorData: () => EditorInitData(
          name: "option-selector",
          input: <* {
            "default": style(),
            "data": [
             ["disc", "disc"],
             ["decimal", "decimal"],
             ["persian", "persian"],
             ["roman", "roman"],
             ["latin", "latin"]]},

          updateCallback: mutState(setStyle, cstring)))]

proc initTableRow: Hooks =
  let el = createElement "tr"

  defHooks:
    dom = () => el
    acceptsAsChild = anyTag

    attachNode = proc(child: TwNode, at: Index) =
      let td = createElement "td"
      td.appendChild child.dom
      attachNodeDefault hooks.self(), child, hooks.dom(), td, at

    detachNode = proc(at: Index) =
      dettachNodeDefault hooks.self(), at, true

# TODO add border config
proc initTable: Hooks =
  let el = createElement "table"

  defHooks:
    dom = () => el
    acceptsAsChild = genAllowedTags @[c"table-row"]

# TODO add max height, height, width, max width OR USE [GRID component]
proc initCustomHtml: Hooks =
  let
    el = createElement "div"
    (content, cset) = genState c""

  defHooks:
    dom = () => el
    acceptsAsChild = noTags
    capture = () => tojs content()

    restore = proc(input: JsObject) =
      cset input.to cstring

    render = genRender:
      el.innerHTML = content()

    settings = () => @[
      SettingsPart(
        field: "HTML code",
        icon: "bi bi-filetype-html",
        editorData: () => EditorInitData(
          name: "raw-text-editor",
          input: toJs content(),
          updateCallback: mutState(cset, cstring)))]

# TODO replace raw-text with custom MarkDown
proc initMd: Hooks =
  let
    el = createElement("div", {"class": "tw-md " & displayInlineClass})
    (content, cset) = genState c""
    # TODO add dir="auto"

  defHooks:
    dom = () => el
    acceptsAsChild = noTags
    capture = () => <*{"content": content()}
    restore = proc(input: JsObject) =
      cset input["content"].to cstring

    render = genRender:
      el.innerHTML = mdparse content()

    settings = () => @[
      SettingsPart(
        field: "markdown code",
        icon: "bi bi-markdown",
        editorData: () => EditorInitData(
          name: "raw-text-editor",
          input: toJs content(),
          updateCallback: mutState(cset, cstring)))]

# TODO declarative schema check & assignment in restore hook

proc initGithubCode: Hooks =
  let
    wrapperEl = createElement("div", {"class": "tw-gh-code"})
    cssLinkEl = createElement("link", {"rel": "stylesheet", "href": ""})
    codeEl = createElement("div", {"class": "tw-gh-code-content"})
    (url, uset) = genState c""

  wrapperEl.append cssLinkEl, codeEl

  defHooks:
    dom = () => wrapperEl
    acceptsAsChild = noTags
    capture = () => <*{"url": url()}
    restore = proc(input: JsObject) =
      uset input["url"].to cstring

    render = genRender:
      some newPromise proc(resolve, fail: proc()) =
        apiGetGithubCode $url(), proc(a: GithubCodeEmbed) =
          cssLinkEl.setAttr "href", a.styleLink
          codeEl.innerHTML = a.htmlCode
          resolve()

    settings = () => @[
      SettingsPart(
        field: "link",
        icon: "bi bi-link-45deg",
        editorData: () => EditorInitData(
          name: "raw-text-editor",
          input: toJs url(),
          updateCallback: mutState(uset, cstring)))]

proc initIncluder: Hooks =
  var lastnoteQuery = c""
  let
    el = createElement("div", {"class": "tw-include-external"})
    (noteQuery, setNoteQuery) = genstate c""
    (inline, inlineSet) = genstate false

  defHooks:
    dom = () => el
    acceptsAsChild = noTags
    capture = () => <*{
      "query": noteQuery(),
      "inline": inline()}

    restore = proc(j: JsObject) =
      setNoteQuery j["query"].to(cstring)
      inlineSet j["inline"].to(bool)

    render = genRender:
      if inline():
        el.classList.add displayInlineClass
      else:
        el.classList.remove displayInlineClass

      if lastnoteQuery != noteQuery():
        purge el
        some newPromise proc(resolve, fail: proc()) =
          apiGetNoteContentQuery $noteQuery(), proc(data: TreeNodeRaw[JsObject]) =
            let fut = deserizalize(
              hooks.componentsTable(),
              data,
              some hooks.dom())

            lastnoteQuery = noteQuery()
            discard fut.then(resolve).catch(fail)
      else:
        result

    settings = () => @[
      SettingsPart(
        field: "note id",
        icon: "bi bi-link-45deg",
        editorData: () => EditorInitData(
          name: "raw-text-editor",
          input: toJs noteQuery(),
          updateCallback: mutState(setNoteQuery, cstring))),

      SettingsPart(
        field: "inline",
        icon: "bi bi-displayport",
        editorData: () => EditorInitData(
          name: "checkbox-editor",
          input: toJs inline(),
          updateCallback: mutState(inlineSet, bool)))]

proc initLinkPreivew: Hooks =
  var lastUrl = c""
  let
    mainEl = createElement("div", {"class": "tw-link-preview card my-3 bg-light border-primary"})

    titleEl = createElement("div", {"class": "tw-link-preview-title card-header",
        "dir": "auto"})
    titleTextEl = createElement("a", {
        "class": "tw-link-preview-title-text card-link",
        "target": "_blank"})
    detailsEl = createElement("div", {"class": "tw-link-preview-details card-body"})
    descEl = createElement("div", {"class": "tw-link-preview-desc card-text text-muted",
        "dir": "auto"})
    photoWrapperEl = createElement("div", {"class": "tw-link-preview-img-wrapper mt-4 text-center"})
    photoEl = createElement("img", {"class": "tw-link-preview-img rounded"})
    
    (url, uset) = genstate c""

  titleEl.append titleTextEl
  photoWrapperEl.append photoEl
  detailsEl.append descEl, photoWrapperEl
  mainEl.append titleEl, detailsEl

  defHooks:
    dom = () => mainEl
    acceptsAsChild = noTags
    capture = () => <*{"url": url()}
    restore = proc(j: JsObject) =
      uset j["url"].to cstring

    render = genRender:
      if lastUrl != url():
        some newPromise proc(resolve, fail: proc()) =
          apiGetLinkPreviewData $url(), proc(resp: LinkPreviewData) =
            destroyChildren hooks.self()

            titleTextEl.innerText = resp.title
            descEl.innerText = resp.desc
            titleTextEl.setAttr "href", url()
            photoEl.setAttr "src", resp.image

            lastUrl = url()
            resolve()
      else:
        result

    settings = () => @[
      # SettingsPart(
        #   field: "",
        #   icon: "bi bi-signpost-fill",
        #   editorData: () => EditorInitData(
        #     name: "option-selector",
        #     input: <* {
        #       "default": dir(),
        #       "data": [
        #         ["auto", "auto"],
        #         ["ltr", "ltr"],
        #         ["rtl", "rtl"]]},
        #     updateCallback: mutState(setDir, cstring))),

      SettingsPart(
        field: "link",
        icon: "bi bi-link-45deg",
        editorData: () => EditorInitData(
          name: "raw-text-editor",
          input: toJs url(),
          updateCallback: mutState(uset, cstring)))]

# TODO
# ----- [more] component :: a drop down with html elements
# ----- Grid [margin/padding/center/left/right/flex+justify+alignment/height/max-height/width/max-width]
# ----- Table Of Contents

proc initConfig: Hooks =
  let
    el = createElement "div"
    (status, setstatus) = genState c""

  defHooks:
    dom = () => el
    acceptsAsChild = anyTag
    status = () => (tsNothing, "")
    # capture = () => tojs configIni()
    # restore = (j: JsObject) => setConfig j.to cstring
    # render = genRender:  discard
    mounted = genMounted: discard

    settings = () => @[
      SettingsPart(
        field: "pin",
        icon: "bi bi-pin",
        editorData: () => EditorInitData(
          name: "raw-text-editor",
          input: toJs status(),
          updateCallback: mutState(setStatus, cstring)))]

# ----- Export ------------------------

defComponent rootComponent,
  "root",
  "bi bi-diagram-3-fill",
  @["root"],
  initRoot

defComponent paragraphComponent,
  "paragraph",
  "bi bi-paragraph",
  @["global", "text", "block"],
  initParagraph

defComponent rawTextComponent,
  "raw-text",
  "bi bi-type",
  @["global", "inline", "text", "raw"],
  initRawText

defComponent linkComponent,
  "link",
  "bi bi-link-45deg",
  @["global", "inline"],
  initLink

defComponent boldComponent,
  "bold",
  "bi bi-type-bold",
  @["global", "inline"],
  initBold

defComponent italicComponent,
  "italic",
  "bi bi-type-italic",
  @["global", "inline"],
  initItalic

defComponent underlineComponent,
  "underline",
  "bi bi-type-underline",
  @["global", "inline"],
  initUnderline

defComponent strikethroughComponent,
  "strike through",
  "bi bi-type-strikethrough",
  @["global", "inline"],
  initStrikethrough

defComponent h1Component,
  "h1",
  "bi bi-type-h1",
  @["global", "title", "block"],
  initTitleH1

defComponent h2Component,
  "h2",
  "bi bi-type-h2",
  @["global", "title", "block"],
  initTitleH2

defComponent h3Component,
  "h3",
  "bi bi-type-h3",
  @["global", "title", "block"],
  initTitleH3

defComponent h4Component,
  "h4",
  "bi bi-type-h4",
  @["global", "title", "block"],
  initTitleH4

defComponent h5Component,
  "h5",
  "bi bi-type-h5",
  @["global", "title", "block"],
  initTitleH5

defComponent h6Component,
  "h6",
  "bi bi-type-h6",
  @["global", "title", "block"],
  initTitleH6

defComponent latexComponent,
  "latex",
  "bi bi-regex",
  @["global", "inline", "block"],
  initLatex

defComponent mdComponent,
  "markdown",
  "bi bi-markdown",
  @["global", "inline", "block"],
  initMd

defComponent verticalSpaceComponent,
  "vertical-space",
  "bi bi-distribute-vertical",
  @["global", "space", "vertical", "block"],
  initVerticalSpace

defComponent imageComponent,
  "image",
  "bi bi-image-fill",
  @["global", "media", "block", "picture"],
  initImage

defComponent videoComponent,
  "video",
  "bi bi-film",
  @["global", "media", "block"],
  initVideo

defComponent listComponent,
  "list",
  "bi bi-list-task",
  @["global", "block", "inline"],
  initList

defComponent tableComponent,
  "table",
  "bi bi-table",
  @["global", "block"],
  initTable

defComponent tableRowComponent,
  "table-row",
  "bi bi-table",
  @[],
  initTableRow

defComponent customHtmlComponent,
  "html",
  "bi bi-filetype-html",
  @["global", "block", "inline"],
  initCustomHtml

defComponent configComponent,
  "config",
  "bi bi-gear-fill",
  @[],
  initConfig

defComponent githubCodeComponent,
  "github",
  "bi bi-github",
  @["global", "block"],
  initGithubCode

defComponent includeCodeComponent,
  "includer",
  "bi bi-puzzle-fill",
  @["global", "block", "inline"],
  initIncluder

defComponent linkPreviewComponent,
  "link preview",
  "bi bi-terminal",
  @["global", "block"],
  initLinkPreivew


proc defaultComponents*: ComponentsTable =
  new result
  result.add [
    rootComponent,
    configComponent,
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
    tableRowComponent,
    githubCodeComponent,
    includeCodeComponent,
    linkPreviewComponent,
    customHtmlComponent]
