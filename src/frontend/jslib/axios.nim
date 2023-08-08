import std/[jsffi, asyncjs, httpcore, jsformdata]
import ../utils/browser

type
  AxiosConfig*[D: JsObject or FormData or cstring] = ref object of JsObject
    headers*: JsObject
    params*: JsObject
    data*: D
    timeout*: int      # default is `0` (no timeout)
    maxRedirects*: int # default 5
    onUploadProgress*: proc(pe: ProgressEvent)
    onDownloadProgress*: proc(pe: ProgressEvent)

  # AxiosRequest* = ref object of JsObject
  AxiosResponse* = ref object of JsObject
    data: JsObject
    status: HttpCode
    statusText: cstring
    headers: JsObject
    config: AxiosConfig[JsObject]


proc axios*(
  `method`, url: cstring,
  config: AxiosConfig = nil
): Future[AxiosResponse] {.importjs: """
  axios({
    method: #,
    url: #,
    config: #})""".}

proc axios*(
  `method`: HttpMethod,
  url: cstring,
  config: AxiosConfig
): Future[AxiosResponse] =
  axios $`method`, url, config
