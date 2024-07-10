import std/[ropes, strformat, strutils, sequtils, os, tables]

import ../urls
import ../database/[models, logic]
import ../../frontend/deps
import ../../common/[package, str, conventions]


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

func icon*(class: string): string =
  fmt"""<i class="fa-solid {class}"></i>"""
  # "fa-regular "

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

proc exploreUserItem(u: User): string = 
  fmt"""
    <div class = "list-group-item list-group-item-action d-flex justify-content-between align-items-center">
      <bold class = "mx-2">
        <a href="{user_profile_url(u.id)}" up-follow up-transition="cross-fade" up-duration="300">
          @{u.username}
        </a>
      </bold>

      <span class = "text-muted fst-italic">
        {u.nickname}
        {iff(isAdmin u, icon "fa-user-shield ms-2", "")}
      </span>
    </div>
  """

proc exploreHtml*(users: seq[User]): string =
  let 
    usersItems = join users.map exploreUserItem

  htmlPage:
    commonPage "explore ", @[], rope fmt"""
      {nav "fa-magnifying-glass", "explore"}

      <div class = "list-group my-4 p-4">
        {usersItems}
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