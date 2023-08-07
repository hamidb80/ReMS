import std/[with, math, options, lenientops, strformat, random, httpcore]
import std/[dom, jsconsole, jsffi, asyncjs, jsformdata, sugar]
import karax/[karax, karaxdsl, vdom, vstyles]
import caster

import ../[hotkeys, browser, ui, axios, conventions]

type
  Percent = range[0.0 .. 100.0]

  UploadStatus = enum
    usPrepare
    usInProgress
    usWait
    usFailed
    usCompleted

  Upload = ref object
    name: cstring
    status: UploadStatus
    progress: Percent
    file: DFile
    promise: Future[AxiosResponse]


  CmpOperator = enum
    lt   #  <
    lte  #  <=
    eq   #  ==
    neq  # !=
    gte  # >=
    gt   #  >
    like #  %


var uploads: seq[Upload]

# TODO add "order by"
# TODO make tag searcher common in all modules [graph, assets, notes]


proc startUpload(u: Upload) =
  # https://github.com/axios/axios/blob/main/examples/upload/index.html

  var
    form = newFormData()
    cfg = AxiosConfig[FormData]()

  form.add "file".cstring, u.file
  cfg.onUploadProgress = proc(pe: ProgressEvent) =
    u.progress = pe.loaded / pe.total
    redraw()

  u.promise = axios(HttpPost, "https://google.com/", cfg)

  discard u.promise.catch proc(r: Error) =
    u.status = usFailed
    echo "failed"
    redraw()

  u.status = usInProgress
  redraw()


proc cancelUpload(u: Upload) =
  # https://stackoverflow.com/questions/38329209/how-to-cancel-abort-ajax-request-in-axios
  discard

proc pushToUpload(files: seq[DFile]) =
  console.log files

  for f in files:
    let u = Upload(
      name: f.name,
      status: usPrepare,
      progress: 0.0,
      file: f)

    uploads.add u
    setTimeout 1000, proc = 
      startUpload u

# ----- Events

proc dropHandler(ev: Event as DragEvent) {.caster.} =
  pushToUpload ev.dataTransfer.filesArray

proc clipboardHandler(e: Event as ClipboardEvent) {.caster.} =
  pushToUpload e.clipboardData.filesArray

# ----- UI

func progressbar(percent: Percent, status: UploadStatus): Vnode =
  buildHtml:
    tdiv(class = "progress limited-progress"):
      tdiv(class = classes {
        "progress-bar": true,
        "bg-primary": status == usInProgress,
        "bg-dark-subtle": status == usPrepare,
        "bg-warning": status == usWait,
        "bg-danger": status == usFailed,
        "bg-success": status == usCompleted,
        "progress-bar-striped progress-bar-animated": status in {usInProgress,
            usPrepare},
      },
          style = style(StyleAttr.width, $iff(status == usInProgress, percent,
              100) & "%"))

func tagSearch(name, color: string,
  compareOperator: Option[CmpOperator]): VNode =

  buildHtml:
    tdiv(class = "form-group d-inline-block mx-2"):
      tdiv(class = "input-group mb-3"):
        span(class = "input-group-text"):
          italic(class = "fa-solid fa-hashtag me-2")
          span:
            text name

        if issome compareOperator:
          button(class = "input-group-text pointer btn btn-outline-primary"):
            let ic =
              case get compareOperator
              of lt: "fa-solid fa-less-than"
              of lte: "fa-solid fa-less-than-equal"
              of eq: "fa-solid fa-equals"
              of neq: "fa-solid fa-not-equal"
              of gte: "fa-solid fa-greater-than-equal"
              of gt: "fa-solid fa-greater-than"
              of like: "fa-solid fa-percent"

            italic(class = ic)

          input(class = "form-control tag-input", `type` = "text")

        tdiv(class = "input-group-text btn btn-outline-danger d-flex align-items-center justify-content-center p-2"):
          italic(class = "fa-solid fa-xmark")

proc createDom: Vnode =
  result = buildHtml tdiv:
    nav(class = "navbar navbar-expand-lg bg-white"):
      tdiv(class = "container-fluid"):
        a(class = "navbar-brand", href = "#"):
          italic(class = "fa-solid fa-box fa-xl me-3 ms-1")
          text "Assets"

    tdiv(class = "p-4 m-4"):
      h6(class = "mb-3"):
        italic(class = "fa-solid fa-arrow-pointer me-2")
        text "Select / Paste / Drag"

      tdiv(class = "rounded p-3 rounded bg-white d-flex flex-column align-items-center justify-content-center"):
        tdiv(class = "form-group w-100"):
          input(class = "form-control",
              `type` = "file",
              multiple = "multiple",
              placeholder = "select as many as files you want!"):

            proc onInput(e: Event, v: VNode) =
              pushToUpload e.currentTarget.filesArray

        tdiv(class = "my-3")

        tdiv(class = """dropper bg-light border-secondary grab
              border border-4 border-dashed rounded-2 user-select-none
              d-flex flex-column justify-content-center align-items-center"""):

          tdiv():
            text "drag file or paste something here"

          tdiv():
            text "when hover"


          proc ondrop(e: Event, v: VNode) =
            e.preventdefault
            dropHandler e

          proc ondragover(e: Event, v: VNode) =
            e.preventdefault

      h6(class = "mt-4 mb-3"):
        italic(class = "fa-solid fa-spinner fa-spin-pulse me-2")
        text "in progress uploads"

      tdiv(class = "list-group mb-4"):
        for u in uploads:
          tdiv(class = "d-flex flex-row align-items-center justify-content-between list-group-item list-group-item-action"):
            text u.name
            progressbar u.progress, u.status

      tdiv(class = "form-group"):
        h6(class = "mb-3"):
          italic(class = "fa-solid fa-hashtag me-2")
          text "search by tags"

        tagSearch("id", "red", some neq)
        tagSearch("extention", "black", some lte)
        tagSearch("time", "gray", none CmpOperator)

        button(class = "btn btn-success w-100 my-2"):
          text "add tag"
          # TODO remove this, add all tags below
          italic(class = "fa-solid fa-plus ms-2")

        h6(class = "mb-3"):
          italic(class = "fa-solid fa-arrow-up-wide-short me-2")
          text "order results by"

      tdiv(class = "form-group"):
        button(class = "btn btn-primary w-100"):
          text "search"
          italic(class = "fa-solid fa-magnifying-glass ms-2")

      tdiv(class = ""):
        # switch list/block view
        for i in 0..10:
          discard # files uploaded


      tdiv(class = "form-group"):
        button(class = "btn btn-warning w-100 mt-3"):
          text "load more"
          italic(class = "fa-solid fa-angles-right ms-2")


when isMainModule:
  document.body.addEventListener "paste", proc(
      e: Event as ClipboardEvent) {.caster.} =
    pushToUpload e.clipboardData.filesArray
    redraw()

  setRenderer createDom
