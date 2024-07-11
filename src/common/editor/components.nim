import std/[jsffi, dom, asyncjs]
import std/[with, options, tables, sugar, strformat]

import ./core
import ../../utils/[browser, js, api]
import ../../../common/[conventions, datastructures, linear_markdown]
import ../../../backend/database/[models]


# FIXME clean up
# TODO declarative schema check & assignment in restore hook | dont use 'to' event 'cast' is better
# TODO ability to add classes to the nodes manually

# ----- Utils -----------

const
  twFocusClass       = "tw-focus-hover"
  twHoverClass       = "tw-mouse-hover"
  displayInlineClass = "d-inline"
  trottleMs          = 100

template defComponent(ident, identstr, icone, tagss, initproc: untyped, gn = false): untyped =
  let ident* = Component(
    name: identstr,
    icon: icone,
    tags: tagss,
    init: initproc,
    isGenerator: gn)


defComponent rawText:
    html =
        span(class="tw-text"):
            [[iff(spaceAround, " ", "")]]
            [[content]]
            [[iff(spaceAround, " ", "")]]

    data =
        content     = ""
        spaceAround = true

    settings =
        ...content
        ?spaceAround

let  initBold          = wrapperTextElement("b",    "tw-bold",           onlyInlines)
let  initItalic        = wrapperTextElement("i",    "tw-italic",         onlyInlines)
let  initUnderline     = wrapperTextElement("u",    "tw-underline",      onlyInlines)
let  initStrikethrough = wrapperTextElement("s",    "tw-strikethrough",  onlyInlines)
let  initSpoiler       = wrapperTextElement("span", "tw-text-spoiler",   onlyInlines)
let  initHighlight     = wrapperTextElement("mark", "tw-text-highlight", onlyInlines)

proc initTitle: Hooks =
    html =
        <>tdiv(class="tw-title [[priority]]")

    data:
        priority: ["h1", "h2", "h3", "h4", "h5", "h6"]

proc initVerticalSpace: Hooks =
    html =
        tdiv(class= "tw-vertical-space my-[[space]]")

    data:
        space: int
    
    settings:
        space: range[1..5]

proc initHorizontalLine: Hooks =
    html =
        hr(class= "tw-horizontal-line")

proc initLink: Hooks =
    html =
        a(class= "text-decoration-none", href="[[url]]", target="_blank")

    data:
        url: string

    settings:
        ..url

proc initLatex: Hooks =
    html =
        tdiv(class="tw-latex")
    
    data:
        content: string = ""
        inline : bool   = false


    settings = 
        ...latex
        ?inline

    
proc initLinearMarkdown: Hooks =
    trottle = 100.ms

    html =
        tdiv(class= "tw-linear-markdown [[displayInlineClass]]")
    
    data:
        content: string = ""
        inline : bool   = false

proc initImage: Hooks =

    html =
        figure(class= "tw-image-wrapper"):
            img(width="[[width]]", height="[[height]]")
            figcaption()

    data:
        url    = ""
        width  = ""
        height = ""
        status = (tsWarning, "no url")

    settings:
        //url
        0width
        0height

proc initVideo: Hooks =
    html =
      tdiv(class= "tw-video-wrapper"):
        video(src="[[url]]", controls, width="[[width]]", height="[[height]]", ?loop="[[loop]]")
    
    data =
      url    : string = ""
      width  : string = ""
      height : string = ""
      loop   : bool   = false 

    settings=
      //url
      0.width
      0.height
      ?loop

proc initList: Hooks =
    html =
      ul(dir="[[dir]]", class="[[tw-list style]]"):
    
    data = 
      style : string = ""  
      dir   : string = ""

    settings = 
        "persian": "list-persian-number"
        "abjad":   "list-abjad"
        "roman":   "list-roman"
        "latin":   "list-latin"
        "decimal": "list-decimal"
        else:       "list-disc"

proc initTableRow: Hooks =
  html =
    tr()

proc initTable: Hooks =
  html =
    table()

proc initCustomHtml: Hooks =
  html =
      tdiv(class= "tw-custom-html"):
        [[content]]

  data=
    content: string = ""

  settings = 
    ...content


proc initGithubGist: Hooks =
  html = 
    tdiv(class= "tw-gh-code"):
      link(rel= "stylesheet", href="")
      tdiv(class= "tw-gh-code-content")

  data = 
    url: string = ""

  settings = 
    //url

proc initLinkPreivew: Hooks =
  html = 
    tdiv(class= "tw-link-preview card my-3 bg-light border-primary"):
      tdiv(class= "tw-link-preview-title card-header", dir= "auto"):
        a(class= "tw-link-preview-title-text card-link text-decoration-none", target= "_blank")

      tdiv(class= "tw-link-preview-details card-body"):
        tdiv(class  = "tw-link-preview-desc card-text text-muted", dir  = "auto")

        tdiv(class= "tw-link-preview-img-wrapper mt-4 text-center"):
          img(class= "tw-link-preview-img rounded")

  data = 
    url      : string = ""
    title    : string = ""
    desc     : string = ""
    imagesrc : string = ""

  settings = 
    //url     
    ..title   
    ...desc   
    //imagesrc


proc initMoreCollapse: Hooks =
  html = 
    details  (class= "tw-more"):
      summary  (class= "tw-more-summary text-center")
      main     (class= "tw-more-body")

proc initRawCode: Hooks =
  html
    pre(class= "tw-raw-code")

  data = 
    content = ""
    inline  = false

  render = genRender:
    el.ctrlClass displayInlineClass, inline()
    el.innerText = content()

  settings =
    ...code
    ?inline

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

defComponent textHighlightComponent,
  "text highlight",
  "bi bi-type-strikethrough",
  @["global", "inline"],
  initHighlight

defComponent textSpoilerComponent,
  "text spoiler",
  "bi bi-type-strikethrough",
  @["global", "inline"],
  initSpoiler

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

defComponent paragraph:
    template = 
        <>tdiv(class= "tw-paragraph [[displayInlineClass?inline]] [[align|aclass]]", dir="[[dir]]")

    states = 
      inline: bool   = false
      dir   : string = "auto"
      align : string = "auto"

    config = 
        dir = 
            ["auto", "auto"]
            ["ltr",  "ltr"]
            ["rtl",  "rtl"]
    
        align
            ["auto",   "auto"]
            ["center", "center"]
            ["left",   "left"]
            ["right",  "right"]

        ?inline



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
    textHighlightComponent,
    textSpoilerComponent,
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
