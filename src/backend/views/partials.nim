import std/[ropes, strformat, paths, strutils, os, tables, times]


import ../routes
import ../../frontend/deps
import ../../common/[package, str]


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


proc extLink(rel, url: string): string =
  fmt"""<link rel="{rel}" href="{url}"/>"""

proc extJs(url: string, defered: bool = false): string =
  fmt"""<script src="{url}" defer></script>"""

proc extCss(url: string): string =
  extLink "stylesheet", url


proc tryBtnLink(link: string): Rope =
  rope fmt"""
    <a class="btn btn-primary" href={link}>Open</a>
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

    <!-- UI libraries -->
    {extCss resolveLib"lib.katex.css"}
    {extCss resolveLib"theme.bootstrap.css"}
    {extCss resolveLib"icons.boostrap.css"}
    {extCss resolveLib"icons.fontawesome.css"}

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
    upper = rope fmt"<html>{commonHead title, deps}"
    lower = rope    "</html>"

  upper &  content & lower


proc htmlPage(htmlDoc: Rope): string =
  tostr rope"<!DOCTYPE html>" & htmlDoc

proc landingPageHtml*: string =
  htmlPage:
    commonPage "intro", @[], rope fmt"""
      <body class="bg-light">
        <h1 class="my-4 text-center w-100">
          <italic class="text-primary">
            <bold>Remember</bold>
          </italic>
          Better With Us
        </h1>

        <h3 class="mt-4 mb-2 text-center w-100">Actions</h3>
        
        <div class="d-flex flex-wrap justify-content-evenly">
          {blockk("Explore", "", "icons/planet.svg", explore_url())}
          {blockk("Profile", "", "icons/user.svg", my_profile_url())}
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
    </body>
    """


when isMainModule:
  echo landingPageHtml()