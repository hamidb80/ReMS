import std/[options, lenientops, strformat, httpcore, sequtils]
import std/[dom, jsconsole, jsffi, asyncjs, jsformdata, sugar]
import karax/[karax, karaxdsl, vdom, vstyles]
import caster

import ../jslib/[hotkeys, axios]
import ../utils/[browser, ui]
import ../../common/[conventions]
import ../../backend/routes

type
  Percent = range[0.0 .. 100.0]

  UploadStatus = enum
    usInProgress
    usFailed
    usCancelled
    usCompleted

  Upload = ref object
    name: cstring
    status: UploadStatus
    progress: Percent
    file: DFile
    promise: Future[AxiosResponse]
    reason: cstring


  Tag = object # import from tags.nim

  Asset = object
    filename: string
    description: string
    mimeType: string
    # owner: ID
    tags: seq[Tag]

  # TODO make tag searcher common in all modules [graph, assets, notes]
  CmpOperator = enum
    lt   #  <
    lte  #  <=
    eq   #  ==
    neq  # !=
    gte  # >=
    gt   #  >
    like #  %

const
  noIndex = -1

var
  uploads: seq[Upload]
  assets: seq[Asset]
  selectedAssetIndex: int = 3 # noIndex


proc startUpload(u: Upload) =
  var
    form = newFormData()
    cfg = AxiosConfig[FormData]()

  form.add u.name, u.file
  cfg.onUploadProgress = proc(pe: ProgressEvent) =
    u.progress = pe.loaded / pe.total * 100
    redraw()

  u.promise = postForm(post_assets_upload_url(), form, cfg)

  discard u.promise.catch proc(e: Error) =
    u.status = usFailed
    u.reason = e.message
    redraw()

  discard u.promise.then proc(r: AxiosResponse) =
    u.status = usCompleted
    redraw()

  u.status = usInProgress
  redraw()


proc cancelUpload(u: Upload) =
  # https://stackoverflow.com/questions/38329209/how-to-cancel-abort-ajax-request-in-axios
  discard

proc pushUploads(files: seq[DFile]) =
  console.log files

  for f in files:
    let u = Upload(
      name: f.name,
      status: usInProgress,
      progress: 0.0,
      file: f)

    startUpload u
    uploads.add u

# ----- Events

proc dropHandler(ev: Event as DragEvent) {.caster.} =
  pushUploads ev.dataTransfer.filesArray

proc clipboardHandler(e: Event as ClipboardEvent) {.caster.} =
  pushUploads e.clipboardData.filesArray

# ----- UI

func statusColor(status: UploadStatus): cstring =
  case status
  of usInProgress: "bg-primary"
  of usFailed: "bg-danger"
  of usCancelled: "bg-warning"
  of usCompleted: "bg-success"

func progressbar(percent: Percent, status: UploadStatus): Vnode =
  let cond = status == usInProgress

  buildHtml:
    tdiv(class = "progress limited-progress"):
      tdiv(
        class = "progress-bar " &
          statusColor(status) &
          iff(cond, "progress-bar-striped progress-bar-animated"),
        style = style(
          StyleAttr.width,
          $iff(cond, percent, 100) & "%"))

func tagSearch(name, color: string,
  compareOperator: Option[CmpOperator]): VNode =

  buildHtml:
    tdiv(class = "form-group d-inline-block mx-2"):
      tdiv(class = "input-group mb-3"):
        span(class = "input-group-text"):
          icon("fa-hashtag me-2")
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

            icon ic

          input(class = "form-control tag-input", `type` = "text")

        tdiv(class = "input-group-text btn btn-outline-danger d-flex align-items-center justify-content-center p-2"):
          icon("fa-xmark")

# TODO add "order by"
proc createDom: Vnode =
  result = buildHtml tdiv:
    nav(class = "navbar navbar-expand-lg bg-white"):
      tdiv(class = "container-fluid"):
        a(class = "navbar-brand", href = "#"):
          icon("fa-box fa-xl me-3 ms-1")
          text "Assets"

    tdiv(class = "p-4 m-4"):
      h6(class = "mb-3"):
        icon("fa-arrow-pointer me-2")
        text "Select / Paste / Drag"

      tdiv(class = "rounded p-3 rounded bg-white d-flex flex-column align-items-center justify-content-center"):
        tdiv(class = "form-group w-100"):
          input(class = "form-control",
              `type` = "file",
              multiple = "multiple",
              placeholder = "select as many as files you want!"):

            proc onInput(e: Event, v: VNode) =
              pushUploads e.currentTarget.filesArray

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
        tdiv(class = "d-flex flex-row justify-content-between align-items-center"):
          tdiv:
            if uploads.anyIt it.status == usInProgress:
              icon("fa-spinner fa-spin-pulse me-2")
            else:
              icon("fa-check-double me-2")

            text "in progress uploads"
          tdiv(class = "btn btn-outline-dark"):
            text "clear"
            icon "fa-trash-can ms-2"

      tdiv(class = "list-group mb-4"):
        for u in uploads:
          tdiv(class = "d-flex flex-row align-items-center justify-content-between list-group-item list-group-item-action"):
            text u.name
            tdiv(class = "d-flex flex-row align-items-center justify-content-between"):
              progressbar u.progress, u.status

              case u.status
              of usInProgress:
                button(class = "ms-2 btn btn-outline-primary rounded"):
                  icon "fa-times"

              of usFailed:
                button(class = "ms-2 btn btn-outline-danger rounded"):
                  icon "fa-sync"

              of usCancelled:
                button(class = "ms-2 btn btn-outline-warning rounded"):
                  icon "fa-sync"

              of usCompleted:
                button(class = "ms-2 btn btn-outline-success rounded"):
                  icon "fa-check"

              # TODO show error message as a tooltip

      tdiv(class = "form-group"):
        h6(class = "mb-3"):
          icon("fa-hashtag me-2")
          text "search by tags"

        tagSearch("id", "red", some neq)
        tagSearch("extention", "black", some lte)
        tagSearch("time", "gray", none CmpOperator)

        button(class = "btn btn-success w-100 my-2"):
          text "add tag"
          # TODO remove this, add all tags below
          icon("fa-plus ms-2")

        h6(class = "mb-3"):
          icon("fa-arrow-up-wide-short me-2")
          text "order results by"

      tdiv(class = "form-group"):
        button(class = "btn btn-primary w-100"):
          text "search"
          icon("fa-magnifying-glass ms-2")


      # uploaded files
      tdiv(class = "list-group my-4"):
        for i in 0..10:
          if i == selectedAssetIndex:
            tdiv(class = "p-4 bg-white"):
              h2:
                text "hello!"

          else:
            tdiv(class = "list-group-item list-group-item-action"):
              # + file type logo like image or video or ...
              bold:
                text " file name"

              # + size
              # + dropdown button


      tdiv(class = "form-group"):
        button(class = "btn btn-warning w-100 mt-3"):
          text "load more"
          icon("fa-angles-right ms-2")


when isMainModule:
  document.body.addEventListener "paste":
    proc(e: Event as ClipboardEvent) {.caster.} =
      pushUploads e.clipboardData.filesArray
      redraw()

  setRenderer createDom
