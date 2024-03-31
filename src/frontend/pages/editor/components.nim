import std/[jsffi, dom, asyncjs]
import std/[with, options, tables, sugar, strformat]

import ./core
import ../../utils/[browser, js, api]
import ../../jslib/[katex]
import ../../../common/[conventions, datastructures, linear_markdown]
import ../../../backend/database/[models]


# FIXME clean up
# TODO declarative schema check & assignment in restore hook | dont use 'to' event 'cast' is better
# TODO ability to add classes to the nodes manually

# ----- Utils -----------

const
  twFocusClass = "tw-focus-hover"
  twHoverClass = "tw-mouse-hover"
  displayInlineClass = "d-inline"
  trottleMs = 100

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

template defComponent(ident, identstr, icone, tagss, initproc: untyped,
    gn = false): untyped =
  let ident* = Component(
    name: identstr,
    icon: icone,
    tags: tagss,
    init: initproc,
    isGenerator: gn)

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
    add father.children, child
    appendChild wrapper, what
  elif 0 == at:
    father.children.insert child, at
    wrapper.prepend what
  else: # 1..children.high
    father.children.insert child, at
    discard wrapper.children[at-1].after what

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

proc attachInstance(comp: Component, hooks: Hooks, ct: ComponentsTable) =
  let n = instantiate(comp, ct)
  hooks.self().attach n, 0
  n.mounted mbUser, tmInteractive


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
      cSet getDefault(input, "content", cstring"")
      spSet getDefault(input, "spaceAround", true)

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

proc wrapperTextElement(tag: string, aac: () -> seq[cstring]): () -> Hooks =
  proc: Hooks =
    let el = createElement tag
    defHooks:
      dom = () => el
      acceptsAsChild = aac
      mounted = genMounted:
        if mode == tmInteractive and by == mbUser:
          let ct = hooks.componentsTable()
          attachInstance ct["raw-text"], hooks, ct

# TODO add highlight
# TODO add spoiler
let
  initBold = wrapperTextElement("b", onlyInlines)
  initItalic = wrapperTextElement("i", onlyInlines)
  initUnderline = wrapperTextElement("u", onlyInlines)
  initStrikethrough = wrapperTextElement("s", onlyInlines)

proc initTitle: Hooks =
  let
    el = createElement "div"
    (priority, pset) = genState 1

  defHooks:
    dom = () => el
    acceptsAsChild = onlyInlines

    capture = () => <*{
      "priority": priority()}

    restore = proc(j: JsObject) =
      if isObject j:
        pset getDefault(j, c"priority", 1) ~~ int

    render = genRender:
      el.className = "tw-title h" & $priority()

    mounted = genMounted:
      if mode == tmInteractive and by == mbUser:
        let ct = hooks.componentsTable()
        attachInstance ct["paragraph"], hooks, ct

    settings = () => @[
      SettingsPart(
        field: "text direction",
        icon: "bi bi-paragraph",
        editorData: () => EditorInitData(
          name: "option-selector",
          input: <* {
            "default": priority(),
            "data": [
              [1, "h1"],
              [2, "h2"],
              [3, "h3"],
              [4, "h4"],
              [5, "h5"],
              [6, "h6"]]},
          updateCallback: mutState(pset, int))),
        ]

proc initParagraph: Hooks =
  let
    el = createElement("div", {"class": "tw-paragraph"})
    (dir, setDir) = genState c"auto"
    (align, setAlgn) = genState c"auto"
    (inline, iset) = genState false

  defHooks:
    dom = () => el
    acceptsAsChild = onlyInlines

    capture = () => <*{
      "inline": inline(),
      "dir": dir(),
      "align": align()}

    restore = proc(j: JsObject) =
      if isObject j:
        setDir getDefault(j, c"dir", c"auto") ~~ cstring
        setAlgn getDefault(j, c"align", c"auto") ~~ cstring
        iset getDefault(j, c"inline", false) ~~ bool

    render = genRender:
      case $dir()
      of "ltr": setAttr el, "dir", "ltr"
      of "rtl": setAttr el, "dir", "rtl"
      else: setAttr el, "dir", "auto"

      el.className = "tw-paragraph"

      case $align()
      of "center": add el.classList, "text-center"
      of "left": add el.classList, "text-start"
      of "right": add el.classList, "text-end"
      else: discard

      if inline():
        add el.classList, displayInlineClass

    mounted = genMounted:
      if mode == tmInteractive and by == mbUser:
        let ct = hooks.componentsTable()
        attachInstance ct["linear markdown"], hooks, ct

    settings = () => @[
      SettingsPart(
        field: "text direction",
        icon: "bi bi-paragraph",
        editorData: () => EditorInitData(
          name: "option-selector",
          input: <* {
            "default": dir(),
            "data": [
              ["auto", "auto"],
              ["ltr", "ltr"],
              ["rtl", "rtl"]]},
          updateCallback: mutState(setDir, cstring))),

      SettingsPart(
        field: "text align",
        icon: "bi bi-signpost-fill",
        editorData: () => EditorInitData(
          name: "option-selector",
          input: <* {
            "default": align(),
            "data": [
              ["auto", "auto"],
              ["center", "center"],
              ["left", "left"],
              ["right", "right"]]},
          updateCallback: mutState(setAlgn, cstring))),

      SettingsPart(
        field: "inline?",
        icon: "bi bi-backspace-fill",
        editorData: () => EditorInitData(
          name: "checkbox-editor",
          input: inline().toJs,
          updateCallback: mutState(iset, bool))),
        ]

proc initVerticalSpace: Hooks =
  let
    el = createElement("div", {"class": "tw-vertical-space"})
    (dir, setDir) = genState c"auto"

  defHooks:
    dom = () => el
    acceptsAsChild = noTags

    capture = () => <*{
      "dir": dir(), }

    restore = proc(input: JsObject) =
      setDir input["dir"].to cstring

    render = genRender:
      el.className = "tw-vertical-space " & dir()

    settings = () => @[
      SettingsPart(
        field: "space from top",
        icon: "bi bi-signpost-fill",
        editorData: () => EditorInitData(
          name: "option-selector",
          input: <* {
            "default": dir(),
            "data": [
              ["my-1", "1"],
              ["my-2", "2"],
              ["my-3", "3"],
              ["my-4", "4"],
              ["my-5", "5"],
              ["my-6", "6"],
              ["my-7", "7"],
              ["my-8", "8"],
              ["my-9", "9"]]},
          updateCallback: mutState(setDir, cstring)))]

proc initHorizontalLine: Hooks =
  let el = createElement("hr", {"class": "tw-horizontal-line"})

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
      setAttr el, "href", url()

    mounted = genMounted:
      setAttr el, "target", "_blank"

      if mode == tmInteractive and by == mbUser:
        let ct = hooks.componentsTable()
        attachInstance ct["raw-text"], hooks, ct

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

proc initLinearMarkdown: Hooks =
  let
    el = createElement("div", {"class": "tw-linear-markdown " &
        displayInlineClass})
    (content, cset) = genState c""
  var
    id: TimeOut

  proc contentSetter(data: JsObject) =
    proc after =
      result.refresh()
      cset data.to cstring
      discard result.render()

    clearTimeout id
    id = settimeout(after, trottleMs)

  proc inss(comp: Component, ct: ComponentsTable): TwNode =
    result = instantiate(comp, ct)
    mounted result, mbDeserializer, tmOutputGeneration

  proc genElemForImpl(hooks: Hooks, str: cstring,
      mode: LinearMarkdownMode): TwNode =
    let
      ct = hooks.componentsTable()
      ename =
        case mode
        of lmmItalic: "italic"
        of lmmBold: "bold"
        of lmmUnderline: "underline"
        of lmmStrikeThrough: "strike through"
        of lmmLatex: "latex"
        of lmmCode: "raw code"

    result = inss(ct[ename], ct)

    case mode
    of lmmLatex, lmmCode:
      restore result, <*{
        "content": cstring str,
        "inline": true}
    else:
      discard

    discard render result

  proc genElemFor(hooks: Hooks, str: cstring, modes: set[
      LinearMarkdownMode]): TwNode =
    let localmodes = modes - {lmmCode, lmmLatex}
    result =
      if lmmCode in modes:
        genElemForImpl hooks, $str, lmmCode

      elif lmmLatex in modes:
        genElemForImpl hooks, $str, lmmLatex

      else:
        let ct = hooks.componentsTable()
        var temp = inss(ct["raw-text"], ct)
        restore temp, <*{
          "content": str,
          "spaceAround": false}
        discard render temp
        temp

    for m in localmodes:
      var temp = genElemForImpl(hooks, str, m)
      attach temp, result, 0
      result = temp

  defHooks:
    dom = () => el
    acceptsAsChild = noTags
    capture = () => <*{
      "content": content()}

    restore = proc(input: JsObject) =
      cset input["content"].to cstring

    render = genRender:
      purge el

      let tw = hooks.self()
      reset tw.children
      for i, n in parseLinearMarkdown $content():
        attach tw, genElemFor(hooks, n.substr, n.modes), i

    settings = () => @[
      SettingsPart(
        field: "linear markdown",
        icon: "bi bi-markdown-fill",
        editorData: () => EditorInitData(
          name: "raw-text-editor",
          input: toJs content(),
          updateCallback: contentSetter))]

proc initImage: Hooks =
  let
    hooks = Hooks()
    wrapper = createElement("figure", {"class": "tw-image-wrapper"})
    img = createElement("img") # TODO add optional "rounded" class
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
      setAttr img, "src", url()
      setAttr img, "style", toInlineCss {
        "width": width(),
        "height": height()}

    mounted = genMounted:
      append wrapper, img, caption
      if mode == tmInteractive and by == mbUser:
        let ct = hooks.componentsTable()
        attachInstance ct["paragraph"], hooks, ct

    attachNode = proc(child: TwNode, at: Index) =
      attachNodeDefault hooks.self(), child, caption, child.dom, at

    settings = () => @[
      SettingsPart(
        field: "url",
        icon: "bi bi-link-45deg",
        editorData: () => EditorInitData(
          name: "file-upload-on-paste",
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
    wrapper = createElement("div", {"class": "tw-video-wrapper"})
    videl = createElement "video"
    (url, setUrl) = genstate c""
    (width, setWidth) = genState c""
    (height, setHeight) = genState c""
    (loop, setLoop) = genState false

  append wrapper, videl

  defHooks:
    dom = () => wrapper
    acceptsAsChild = noTags

    capture = () => <* {
      "url": url(),
      "loop": loop(),
      "width": width(),
      "height": height()}

    restore = proc(j: JsObject) =
      setUrl j["url"].to cstring
      setLoop j["loop"].to bool
      setWidth j["width"].to cstring
      setHeight j["height"].to cstring

    render = genRender:
      echo url(), " <<"
      setAttr videl, "src", url()
      setAttr videl, "style", toInlineCss {
        "width": width(),
        "height": height()}
      toggleAttr videl, "loop", loop()


    mounted = genMounted:
      setAttr videl, "controls", ""

    settings = () => @[
      SettingsPart(
        field: "url",
        icon: "bi bi-link-45deg",
        editorData: () => EditorInitData(
          name: "file-upload-on-paste",
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
          updateCallback: mutState(setHeight, cstring))),

      SettingsPart(
        field: "loop?",
        icon: "bi bi-repeat",
        editorData: () => EditorInitData(
          name: "checkbox-editor",
          input: toJs loop(),
          updateCallback: mutState(setLoop, bool)))]

proc initList: Hooks =
  let
    ul = createElement "ui"
    (style, setStyle) = genState c""
    (dir, setdir) = genState c""

  defHooks:
    dom = () => ul
    acceptsAsChild = anyTag

    capture = () => <*{
      "style": style(),
      "dir": dir()}

    restore = proc(j: JsObject) =
      if isObject j:
        setStyle getDefault(j, c"style", c"list-disc") ~~ cstring
        setdir getDefault(j, c"dir", c"auto") ~~ cstring

    render = genRender:
      case $dir()
      of "ltr": setAttr ul, "dir", "ltr"
      of "rtl": setAttr ul, "dir", "rtl"
      else: setAttr ul, "dir", "auto"

      let c =
        case $style()
        of "persian": "list-persian-number"
        of "abjad": "list-abjad"
        of "roman": "list-roman"
        of "latin": "list-latin"
        of "decimal": "list-decimal"
        else: "list-disc"

      ul.className = "tw-list w-100"
      add ul.classList, c

    attachNode = proc(child: TwNode, at: Index) =
      let li = createElement "li"
      appendChild li, child.dom
      attachNodeDefault hooks.self(), child, hooks.dom(), li, at

    detachNode = proc(at: Index) =
      dettachNodeDefault hooks.self(), at, true

    settings = () => @[
      SettingsPart(
        field: "style",
        icon: "bi bi-signpost-fill",
        editorData: () => EditorInitData(
          name: "option-selector",
          input: <* {
            "default": style(),
            "data": [
             ["disc", "disc"],
             ["decimal", "decimal"],
             ["persian", "persian"],
             ["abjad", "abjad"],
             ["roman", "roman"],
             ["latin", "latin"]]},

          updateCallback: mutState(setStyle, cstring))),

      SettingsPart(
        field: "text direction",
        icon: "bi bi-paragraph",
        editorData: () => EditorInitData(
          name: "option-selector",
          input: <* {
            "default": dir(),
            "data": [
              ["auto", "auto"],
              ["ltr", "ltr"],
              ["rtl", "rtl"]]},
          updateCallback: mutState(setDir, cstring)))]

proc initTableRow: Hooks =
  let el = createElement "tr"

  defHooks:
    dom = () => el
    acceptsAsChild = anyTag

    attachNode = proc(child: TwNode, at: Index) =
      let td = createElement "td"
      appendChild td, child.dom
      attachNodeDefault hooks.self(), child, hooks.dom(), td, at

    detachNode = proc(at: Index) =
      dettachNodeDefault hooks.self(), at, true

# TODO add border settings
proc initTable: Hooks =
  let el = createElement "table"

  defHooks:
    dom = () => el
    acceptsAsChild = genAllowedTags @[c"table-row"]

proc initCustomHtml: Hooks =
  let
    el = createElement("div", {"class": "tw-custom-html"})
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

proc initGithubGist: Hooks =
  let
    wrapperEl = createElement("div", {"class": "tw-gh-code"})
    cssLinkEl = createElement("link", {"rel": "stylesheet", "href": ""})
    codeEl = createElement("div", {"class": "tw-gh-code-content"})
    (url, uset) = genState c""

  append wrapperEl, cssLinkEl, codeEl

  defHooks:
    dom = () => wrapperEl
    acceptsAsChild = noTags
    capture = () => <*{"url": url()}
    restore = proc(input: JsObject) =
      uset input["url"].to cstring

    render = genRender:
      some newPromise proc(resolve, fail: proc()) =

        proc done(a: GithubCodeEmbed) =
          cssLinkEl.setAttr "href", a.styleLink
          codeEl.innerHTML = a.htmlCode
          resolve()

        proc noo =
          codeEl.innerText = "fail to fetch gist in url: " & url()
          resolve()

        apiGetGithubCode $url(), done, noo

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

    titleWrapperEl = createElement("div", {
      "class": "tw-link-preview-title card-header", "dir": "auto"})
    titleLinkEl = createElement("a", {
        "class": "tw-link-preview-title-text card-link",
        "target": "_blank"})

    detailsEl = createElement("div", {"class": "tw-link-preview-details card-body"})
    descEl = createElement("div", {
      "class": "tw-link-preview-desc card-text text-muted",
      "dir": "auto"})

    photoWrapperEl = createElement("div", {
        "class": "tw-link-preview-img-wrapper mt-4 text-center"})
    photoEl = createElement("img", {"class": "tw-link-preview-img rounded"})

    (url, uset) = genstate c""
    (title, tset) = genstate c""
    (desc, dset) = genstate c""
    (imagesrc, iset) = genstate c""

  append titleWrapperEl, titleLinkEl
  append photoWrapperEl, photoEl
  append detailsEl, descEl, photoWrapperEl
  append mainEl, titleWrapperEl, detailsEl

  defHooks:
    dom = () => mainEl
    acceptsAsChild = noTags

    capture = () => <*{
      "url": url(),
      "title": title(),
      "desc": desc(),
      "image": imagesrc(),
    }

    restore = proc(j: JsObject) =
      uset getDefault(j, "url", cstring"")
      tset getDefault(j, "title", cstring"")
      dset getDefault(j, "desc", cstring"")
      iset getDefault(j, "image", cstring"")

      lasturl = imagesrc()

    refresh = proc =
      setAttr titleLinkEl, "href", url()
      setAttr photoEl, "src", imagesrc()
      titleLinkEl.innerText = title()
      descEl.innerText = desc()

    render = genRender:
      hooks.refresh()

      if lastUrl != url():
        some newPromise proc(resolve, fail: proc()) =
          apiGetLinkPreviewData $url(), proc(resp: LinkPreviewData) =
            lastUrl = url()

            iset resp.image
            tset resp.title
            dset resp.desc

            let tw = hooks.self()
            clearChildren tw

            hooks.refresh()
            resolve()
      else:
        result

    settings = () => @[
      SettingsPart(
        field: "link",
        icon: "bi bi-link-45deg",
        editorData: () => EditorInitData(
          name: "linear-text-editor",
          input: toJs url(),
          updateCallback: mutState(uset, cstring))),

      SettingsPart(
        field: "title",
        icon: "bi bi-link-45deg",
        editorData: () => EditorInitData(
          name: "raw-text-editor",
          input: toJs title(),
          updateCallback: mutState(tset, cstring))),

      SettingsPart(
        field: "description",
        icon: "bi bi-link-45deg",
        editorData: () => EditorInitData(
          name: "raw-text-editor",
          input: toJs desc(),
          updateCallback: mutState(dset, cstring))),

      SettingsPart(
        field: "image link",
        icon: "bi bi-link-45deg",
        editorData: () => EditorInitData(
          name: "linear-text-editor",
          input: toJs imagesrc(),
          updateCallback: mutState(iset, cstring))),
      ]

proc initMoreCollapse: Hooks =
  let
    wrapperEl = createElement("details", {"class": "tw-more"})
    summaryEl = createElement("summary", {
        "class": "tw-more-summary text-center"})
    mainEl = createElement("main", {"class": "tw-more-body"})

  # TODO add option to center the summary element
  append wrapperEl, summaryEl, mainEl

  defHooks:
    dom = () => wrapperEl

    role = proc(i: Index): string =
      case i
      of 0: "summary"
      else: "body"

    acceptsAsChild = anyTag
    attachNode = proc(child: TwNode, at: Index) =
      let self = hooks.self()
      case at
      of 0:
        if 0 < self.children.len:
          prepend mainEl, self.children[0].dom

        attachNodeDefault self, child, summaryEl, child.dom, at

      else:
        attachNodeDefault self, child, mainEl, child.dom, at


    detachNode = proc(at: Index) =
      let self = hooks.self()
      case at
      of 0:
        purge summaryEl
        if self.children.len > 1:
          append summaryEl, self.children[1].dom
      else:
        discard

      dettachNodeDefault hooks.self(), at, false

# TODO add flex/justify/alignment settings
proc initGrid: Hooks =
  let
    el = createElement("div", {"class": "tw-grid"})
    (margin, setm) = genState c""
    (padding, setp) = genState c""
    (width, setw) = genState c""
    (height, seth) = genState c""
    (maxWidth, setmw) = genState c""
    (maxHeight, setmh) = genState c""
    (verticalSpaceItems, setvsi) = genState 0
    (horzontalSpaceItems, sethsi) = genState 0

  template sss(namee, icone: string, refVal, setter): untyped =
    SettingsPart(
      field: namee,
      icon: icone,
      editorData: () => EditorInitData(
        name: "linear-text-editor",
        input: toJs refVal(),
        updateCallback: mutState(setter, cstring)))


  defHooks:
    dom = () => el
    acceptsAsChild = anyTag
    capture = () => <*{
      "margin": margin(),
      "padding": padding(),
      "width": width(),
      "height": height(),
      "maxWidth": maxWidth(),
      "maxHeight": maxHeight(),
      "verticalSpaceItems": verticalSpaceItems(),
      "horzontalSpaceItems": horzontalSpaceItems(),
      }

    restore = proc(input: JsObject) =
      setm getDefault(input, "margin", cstring"")
      setp getDefault(input, "padding", cstring"")
      setw getDefault(input, "width", cstring"")
      seth getDefault(input, "height", cstring"")
      setmw getDefault(input, "maxWidth", cstring"")
      setmh getDefault(input, "maxHeight", cstring"")
      setvsi getDefault(input, "verticalSpaceItems", 0)
      sethsi getDefault(input, "horzontalSpaceItems", 0)

    render = genRender:
      setAttr el, "style", fmt"""
        margin: {margin()};
        padding: {padding()};
        width: {width()};
        height: {height()};
        max-width: {maxWidth()};
        max-height: {maxHeight()};
      """

      let
        myc = " items-my-" & $verticalSpaceItems()
        mxc = " items-mx-" & $horzontalSpaceItems()

      el.setAttr "class", "tw-grid" & myc & mxc

    settings = () => @[
      sss("margin", "bi bi-border-inner", margin, setm),
      sss("padding", "bi bi-border-outer", padding, setp),
      sss("width", "bi bi-arrows", width, setw),
      sss("height", "bi bi-arrows-vertical", height, seth),
      sss("max width", "bi bi-arrows", maxWidth, setmw),
      sss("max height", "bi bi-arrows-vertical", maxHeight, setmh),
      SettingsPart(
        field: "vertical space between components",
        icon: "bi bi-signpost-fill",
        editorData: () => EditorInitData(
          name: "option-selector",
          input: <* {
            "default": verticalSpaceItems(),
            "data": [
              [0, "0"],
              [1, "1"],
              [2, "2"],
              [3, "3"],
              [4, "4"]]},
          updateCallback: mutState(setvsi, int))),
      SettingsPart(
        field: "horizontal space between components",
        icon: "bi bi-signpost-fill",
        editorData: () => EditorInitData(
          name: "option-selector",
          input: <* {
            "default": horzontalSpaceItems(),
            "data": [
              [0, "0"],
              [1, "1"],
              [2, "2"],
              [3, "3"],
              [4, "4"]]},
          updateCallback: mutState(sethsi, int)))]

proc initQuote: Hooks =
  let
    el = createElement("div", {"class": "tw-quote"})

  defHooks:
    dom = () => el
    acceptsAsChild = anyTag

proc initRawCode: Hooks =
  let
    el = createElement("pre", {"class": "tw-raw-code"})
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
      el.innerText = content()

    settings = () => @[
      SettingsPart(
        field: "code",
        icon: "bi bi-code-slash",
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

# ----- Export ------------------------

defComponent rootComponent,
  "root",
  "bi bi-diagram-3-fill",
  @["root"],
  initRoot

defComponent paragraphComponent,
  "paragraph",
  "bi bi-paragraph",
  @["global", "text", "inline", "block"],
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

defComponent latexComponent,
  "latex",
  "bi bi-regex",
  @["global", "inline", "block"],
  initLatex

defComponent linearMdComponent,
  "linear markdown",
  "bi bi-markdown-fill",
  @["global", "inline", "block"],
  initLinearMarkdown,
  true

defComponent titleComponent,
  "title",
  "bi bi-type-h1",
  @["global", "inline", "block"],
  initTitle

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

defComponent githubGistComponent,
  "github",
  "bi bi-github",
  @["global", "block"],
  initGithubGist

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

defComponent moreCollapseComponent,
  "more",
  "bi bi-three-dots",
  @["global", "block"],
  initMoreCollapse

defComponent horizontalLineComponent,
  "break line",
  "bi bi-dash-lg",
  @["global", "block"],
  initHorizontalLine

defComponent gridComponent,
  "grid",
  "bi bi-columns-gap",
  @["global", "block"],
  initGrid

defComponent rawCodeComponent,
  "raw code",
  "bi bi-code-slash",
  @["global", "block", "inline"],
  initRawCode

defComponent quoteComponent,
  "quote",
  "bi bi-quote",
  @["global", "block"],
  initQuote


proc defaultComponents*: ComponentsTable =
  new result
  add result, [
    rootComponent,
    rawTextComponent,
    paragraphComponent,
    linkComponent,
    boldComponent,
    italicComponent,
    strikethroughComponent,
    latexComponent,
    linearMdComponent,
    titleComponent,
    verticalSpaceComponent,
    imageComponent,
    videoComponent,
    listComponent,
    tableComponent,
    tableRowComponent,
    githubGistComponent,
    includeCodeComponent,
    linkPreviewComponent,
    moreCollapseComponent,
    horizontalLineComponent,
    gridComponent,
    rawCodeComponent,
    quoteComponent,
    customHtmlComponent]
