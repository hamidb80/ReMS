import std/[ropes, strformat, strutils, sequtils, os, tables]

import ../urls
import ../utils/web
import ../database/[models, logic]
import ../../frontend/deps
import ../../common/[package, str, types, conventions]


type
  SearchableClass = enum
    scUsers =  "users"
    scNotes =  "notes"
    scBoards = "boards"
    scAssets = "assets"

  GeneralCardButtonKind = enum
    gcbkLink
    gcbkAction

  GeneralCardButton* = object
    icon: string
    colorClass: string

    case kind: GeneralCardButtonKind
    of gcbkAction:
      isDangerous: bool
      action: proc()

    of gcbkLink:
      url: string


# ----- helpers -----------------------------------------------------

func normalizeOsName(url: string): string =
  for ch in url:
    result.add:
      case ch
      of 'a'..'z', 'A'..'Z', '0'..'9', '_', '-', '.': ch
      else: '-'

proc localize(url: string): string =
  dist_url normalizeOsName url.splitPath.tail

proc resolveLib(key: string): string =
  assert key in extdeps
  dist_url "lib" / key

# ----- essence -----------------------------------------------------

proc extLink(rel, url: string): string =
  fmt"""<link rel="{rel}" href="{url}"/>"""

proc extJs(url: string, defered: bool = false): string =
  fmt"""<script src="{url}" defer></script>"""

proc extCss(url: string): string =
  extLink "stylesheet", url

# ----- mini components ----------------------------------------------

func icon*(faClass: string): string =
  ## Font-Awesome solid icon
  fmt"""<i class="fa-solid {faClass}"></i>"""

func iconr*(faClass: string): string =
  ## Font-Awesome regular icon
  fmt"""<i class="fa-regular {faClass}"></i>"""


proc tryBtnLink(link: string): Rope =
  rope fmt"""
    <a class="btn btn-primary" href={link} up-cache="false" up-follow up-transition="cross-fade" up-duration="300">Open</a>
  """

proc blockk(title, desc, icon, link: string): Rope =
  let b = 
    if link != "":
      fmt"<div class='mt-2'>{tryBtnLink link}</div>"
    else:
      ""

  rope fmt"""
    <div class="p-3 my-4 card">
      <div class="card-body d-flex flex-row justify-content-between">
        <div class="d-flex flex-column align-items-center justify-content-evenly me-3 minw-30">
          <h3 class="text-center">
            {title}
          </h3>
          <img src="{dist_url icon}"/>
          {b}  
        </div>
        <div>{desc}</div>
      </div>
    </div>
  """

# ----- partials -----------------------------------------------------

proc commonHead(pageTitle: string, extra: openArray[string]): Rope =
  rope fmt"""
  <head>
    <meta charset="UTF-8"/>
    <meta name="viewport" content="width=device-width, initial-scale=1.0"/>

    <title>{pageTitle}</title>
    {extLink "icon", localize "./favicon.png"}

    <!-- JS libraries -->
    {extJs resolveLib"lib.konva.js"}
    {extJs resolveLib"lib.katex.js"}
    {extJs resolveLib"lib.axios.js"}
    {extJs resolveLib"lib.unpoly.js"}


    <!-- UI libraries -->
    {extCss resolveLib"lib.katex.css"}
    {extCss resolveLib"theme.bootstrap.css"}
    {extCss resolveLib"icons.boostrap.css"}
    {extCss resolveLib"icons.fontawesome.css"}
    {extCss resolveLib"lib.unpoly.css"}

    <!-- font -->
    <link rel="preconnect" href="https://fonts.googleapis.com"             />
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin="" />
    {extCss extdeps["fonts.google.css"]}

    <!-- custom -->
    {extCss localize apv"./custom.css"}

    <!-- extra -->
    {join extra} 
  </head>
  """

proc commonPage(title: string, deps: openarray[string], content: Rope): Rope =
  let 
    upper = rope fmt"""
      <html>
      {commonHead title, deps}
      <body class="bg-light">
        <main>
    """
    
    lower = rope """
        </main>
      </body>
      </html>
    """

  upper & content & lower

proc htmlPage(htmlDoc: Rope): string =
  tostr rope"<!DOCTYPE html>" & htmlDoc

# ----- pages -----------------------------------------------------

proc landingPageHtml*: string =
  htmlPage:
    commonPage "intro", @[], rope fmt"""
        <h1 class="my-4 text-center w-100">
          <italic class="text-primary">
            <bold>Remember</bold>
          </italic>
          Better With Us
        </h1>

        <h3 class="mt-4 mb-2 text-center w-100">Actions</h3>
        
        <div class="d-flex flex-wrap justify-content-evenly">
          {blockk("Explore", "", "icons/planet.svg", explore_url())}
          {blockk("Profile", "", "icons/user.svg",   my_profile_url())}
        </div>

        <h3 class="mt-4 mb-2 text-center w-100">parts</h3>
        <div class="d-flex flex-wrap justify-content-evenly">
          {blockk("Notes", "", "icons/pen-writing-on-paper.svg", "")}
          {blockk("Files", "", "icons/inbox-archive.svg", "")}
          {blockk("Boards", "", "icons/share-circle.svg", "")}
          {blockk("Tags", "", "icons/tag.svg", "")}
        </div>

        <h3 class="mt-4 mb-2 text-center w-100">Features</h3>
        <div class="d-flex flex-wrap justify-content-evenly">
          {blockk("Save Time", "", "icons/clock-square.svg", "")}
          {blockk("Colorful", "", "icons/palette.svg", "")}
          {blockk("Remember", "", "icons/repeat.svg", "")}
          {blockk("Open Source", "", "icons/hand-heart.svg", "https://github.com/hamidb80/rems")}
        </div>

        <footer class="app-footer m-0  card text-white bg-primary rounded-0">
          <div class="card-body">
            <h4 class="card-title">Still waiting?</h4>

            <p class="card-text">
              WTF man? Just click on `explore` and have fun remembering!
            </p>
          </div>

          <div class="card-footer text-center">
            created with passion 
            {icon "fa-heart"}
          </div>

          <div class="card-footerer text-center p-1">
            version {packageVersion} - built at N/A
          </div>
        </footer>
    """

func nav(iconCls, title: string): string = 
  fmt"""
    <nav id="main-nav-bar" class="navbar navbar-expand-lg bg-white" up-hungry>
      <div class="container-fluid">
        <a class="navbar-brand" href="/" up-transition="cross-fade" up-duration="300">
          {icon iconCls & " fa-xl me-3 ms-1"}
          {title}
        </a>
      </div>
    </nav>
  """

func signInUpForm(fname, fields: string): string = 
  fmt"""
    <div class="card border-secondary m-3 d-flex justify-content-center">
      <div class="card-header">
        {fname}
      </div>

      <div class="card-body p-4">
        <form class="form-group" action="." method="post" up-submit up-transition="cross-fade" up-duration="300">
          {fields}
        </form>
    </div>
  """

func upPagination(title, icn, link: string): string = 
  fmt"""
    <li class="page-item" up-nav>
      <a class="page-link" href="{link}" up-follow up-target=".card-header, .card-body" up-transition="cross-fade" up-duration="300">
        <span class="me-2">{title}</span>
        {icon icn}
      </a>
    </li>
  """

proc signInUpFormHeader(fname: string): Rope =
  rope fmt"""
    {nav "fa-user", fname}
    
    <ul class="pagination pagination-lg d-flex justify-content-center mt-2">
      {upPagination "sign in", "fa-key",      signin_url()}
      {upPagination "sign up", "fa-user-pen", signup_url()}
    </ul>
  """

proc signUpFormHtml*: string =
  htmlPage:
    commonPage "sign up", @[], rope fmt"""
      {signInUpFormHeader "sign up"}

      <div class="alert alert-warning m-4">
        <h4 class="alert-heading">
          Sign up via form is disabled
        </h4>
        <p class="mb-0">
          for signin-up, get activation code from the bot
        </p>
      </div>
    """

proc signInFormHtml*: string =
  let 
    fields = fmt"""
      <label class="form-check-label">username: </label>
      <input type="text" name="username" class="form-control"/>

      <label class="form-check-label">pass: </label>
      <input type="password" name="password" class="form-control">

      <button type="submit" class="btn btn-success w-100 mt-2 mb-4" name="form">
        sign in!
        {icon "mx-2 fa-sign-in"}
      </button>


      <label class="form-check-label">code: </label>
      <input type="text" name="code" class="form-control">

      <button type="submit" class="btn btn-success w-100 mt-2 mb-4">
        sign in!
        {icon "mx-2 fa-sign-in"}
      </button>
    """

  htmlPage:
    commonPage "sign in", @[], rope fmt"""
      {signInUpFormHeader "sign in"}
      {signInUpForm       "sign in", fields}
    """


proc profileHtml*(u: User): string =
  htmlPage:
    commonPage "profile", @[], rope fmt"""
      {nav "fa-address-card", "profile page"}

      @{u.username} - {u.nickname}

      <a href="{signout_url()}" up-cache="false" up-follow up-transition="cross-fade" up-duration="300">
        sign out
      </a>
    """



func iconClass(sc: SearchableClass): string =
  case sc
  of scUsers:  "fa-users"
  of scNotes:  "fa-note-sticky"
  of scBoards: "fa-diagram-project"
  of scAssets: "fa-file"

func pageLink(sc: SearchableClass): string =
  case sc
  of scUsers:  u"explore-users"()
  of scNotes:  u"explore-notes"()
  of scBoards: u"explore-boards"()
  of scAssets: u"explore-assets"()

proc tagViewC*(
  t: Tag,
  value: string,
  clickHandler: proc()
): string =
  let hasValue = value != ""

  fmt"""
    <div class="d-inline-flex align-items-center py-2 px-3 mx-2 my-3 badge border-1 solid-border rounded-pill pointer tag"
      style = "
        background:  {toColorString t.theme.bg};
        color:       {toColorString t.theme.fg};
        borderColor: {toColorString t.theme.fg};
    ">
      if isAscii t.icon[0]:
        icon $t.icon
      else:
        span:
          text t.icon

      if t.showName or hasValue:
        span(dir = "auto", class="ms-2"):
          text t.label

          if hasValue:
            text ": "
            text value
  """

proc tagViewC*(
  tagsDB: Table[Str, Tag],
  label: Str,
  value: Str,
  clickHandler: proc()
): string =
  let tag =
    if label in tagsDB: tagsDB[label]
    else: defaultTag label

  tagViewC tag, value, clickHandler

func generalCardBtnLink*(icon, colorClass, url: string): GeneralCardButton =
  GeneralCardButton(
    icon: icon,
    colorClass: colorClass,
    kind: gcbkLink,
    url: url)

func generalCardBtnAction*(icon, colorClass: string,
    action: proc(), isDangerous = false): GeneralCardButton =
  GeneralCardButton(
    icon: icon,
    colorClass: colorClass,
    kind: gcbkAction,
    action: action,
    isDangerous: isDangerous)

proc generalCardButtonView(b: GeneralCardButton): string =
  let cls = fmt"btn mx-1 btn-compact btn-outline-{b.colorClass}"

  case b.kind
  of gcbkLink:
    fmt"""
      <a class="{cls}", href={b.url}>
        {icon b.icon}
      </a>
    """

  of gcbkAction:
    fmt"""
      <button class="{cls}">
        {icon b.icon}
      </button>
    """
    
proc generalCardView*(
  posterImageUrl: string,
  content: string,
  rels: openArray[RelMinData],
  tagsDB: Table[Str, Tag],
  btns: openArray[GeneralCardButton],
): string =
  fmt"""
    <div class="masonry-item card my-3 border rounded bg-white">
      if posterImageUrl != "":
        <div class="d-flex bg-light card-img justify-content-center overflow-hidden">
          <img src={posterImageUrl}/>
        </div>

      <div class="card-body">
        {content}

        <div class="mt-2 tag-list">
          for r in rels:
            tagViewC tagsDB, r.label, r.value, noop
        </div>
      </div>

      if btns.len != 0:
        <div class="card-footer d-flex justify-content-center">
          for b in btns:
            generalCardButtonView b
        </div>
    </div>
  """

proc exploreUserItem(u: User): string = 
  fmt"""
    <div class="list-group-item list-group-item-action d-flex justify-content-between align-items-center">
      <bold class="mx-2">
        <a href="{user_profile_url(u.id)}" up-follow up-transition="cross-fade" up-duration="300">
          @{u.username}
        </a>
      </bold>

      <span class="text-muted fst-italic">
        {u.nickname}
        {iff(isAdmin u, icon "fa-user-shield ms-2", "")}
      </span>
    </div>
  """


proc exploreWrapperHtml(page, body: string): string =
  let 
    scls = join SearchableClass.mapIt fmt"""
      <li class="page-item">
        <a class="page-link" href="{pageLink it}" up-follow up-transition="cross-fade" up-duration="300">
          {icon iconClass it}
          <span class="ms-2">{it}</span>
        </a>
      </li>
    """

    views = join (1..4).toseq.mapit fmt"""
      <li class="page-item">
        <a class="page-link" href="#">{it}</a>
      </li>"""

  htmlPage:
    commonPage fmt"explore {page}", @[], rope fmt"""
      {nav "fa-magnifying-glass", "explore"}

      <div class="d-flex justify-content-around align-items-center flex-wrap my-4">
        <ul class="pagination pagination-lg">
          {scls}
        </ul>

        <ul class="pagination pagination-lg">
          {views}
        </ul>
      </div>

      {body}
    """

proc exploreHtml*(): string =
  exploreWrapperHtml "users", fmt"""
    choose...
  """

proc exploreUsersHtml*(users: seq[User]): string =
  let usersItems = join users.map exploreUserItem

  exploreWrapperHtml "users", fmt"""
    <div class="list-group my-4 p-4">
      {usersItems}
    </div>
  """


proc notePreviewC(n: NoteItemView): string =
  let
    inner = fmt"""
      <div class="tw-content">
        loading...
      </div>
    """
    deleteIcon =
      if true: "fa-exclamation-circle"
      else:    "fa-trash"

  var btns = @[
    generalCardBtnLink("fa-glasses", "info",  note_preview_url n.id),
    generalCardBtnAction("fa-sync", "primary", ),
    generalCardBtnAction("fa-copy", "primary", )]

  if issome me:
    add btns, [
      generalCardBtnAction("fa-tags", "success", goToTagManager),
      generalCardBtnLink("fa-pen", "warning", get_note_editor_url n.id),
      generalCardBtnAction(deleteIcon, "danger", deleteAct)]

  generalCardView "", inner, n.rels, tags, btns

proc exploreNotesHtml*(notes: seq[NoteItemView]): string =
  exploreWrapperHtml "Notes", fmt"""
    Notes!
  """


proc boardItemViewC(b: BoardItemView): VNode =
  let
    inner = buildHtml:
      h3(dir = "auto"):
        text b.title

    url =
      if issome b.screenshot:
        get_asset_short_hand_url get b.screenshot
      else:
        ""

    deleteIcon =
      if b.id in wantToDelete: "fa-exclamation-circle"
      else: "fa-trash"

  proc deleteBoardAct =
    if b.id in wantToDelete:
      deleteBoard b.id
      discard fetchBoards()
    else:
      add wantToDelete, b.id


  var btns = @[
    generalCardBtnLink("fa-eye", "info", get_board_edit_url b.id)]

  if issome me:
    add btns, generalCardBtnAction(deleteIcon, "danger", deleteBoardAct)

  generalCardView url, inner, b.rels, tags, btns

proc exploreBoardsHtml*(boards: seq[BoardItemView]): string =
  exploreWrapperHtml "Boards", fmt"""
    Boards!
  """

proc assetItemComponent(a: AssetItemView): string =
  fmt"""
    <div class="list-group-item list-group-item-action d-flex justify-content-between align-items-center">
      <div>
        <span>#{a.id}</span>

        <bold class="mx-2">
          <a href={previewLink}>
            {a.name}
          </a>

        <span class="text-muted fst-italic">
          ({a.size.int} B)
        </span>
      </div>

      <div class="d-flex flex-row align-items-center">
        <div>
          for r in a.rels:
            if r.label in tags:
              {tagViewC tags, r.label, r.value, noop}
        </div>

        <button class="mx-2 btn btn-outline-dark>
          {icon "fa-chevron-down"}
        </button>
      </div>
    </div>
  """


proc redirectingHtml*(link: string): string =
  htmlPage:
    commonPage "redirecting ...", @[], rope fmt"""
      <a href="{link}" up-follow up-transition="cross-fade" up-duration="300">
        redirecting ...
      </a>
    """


when isMainModule:
  echo ""