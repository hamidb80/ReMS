import std/[with, strutils, sequtils, options]
import std/[dom, jsconsole, jsffi]

import karax/[karax, karaxdsl, vdom, vstyles]
import caster

import ../components/[snackbar]
import ../../backend/database/models
import ../../common/[conventions, datastructures, types]
import ../utils/[browser, ui, api, js]



type
  AppState = enum
    asInit
    asSelectIcon

var
  state = asInit
  selectedTagI = noIndex
  currentTag: Tag
  tags: seq[Tag]
  colors: seq[ColorTheme]


proc fetchTags =
  apiGetTagsList proc (ts: seq[Tag]) =
    tags = ts
    redraw()

proc createDom: Vnode =
  result = buildHtml tdiv:
    snackbar()

    nav(class = "navbar navbar-expand-lg bg-white"):
      tdiv(class = "container-fluid"):
        a(class = "navbar-brand", href = "#"):
          icon "fa-search fa-xl me-3 ms-1"
          text "Explore"


proc init* =
  setRenderer createDom
  fetchTags()

when isMainModule: init()
