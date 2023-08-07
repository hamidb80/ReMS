import std/[jsffi, asyncjs, httpclient]
import ./browser

type
  AxiosConfig* = ref object of JsObject
    headers*: JsObject
    params*: JsObject
    data*: JsObject
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
    config: AxiosConfig
    # request: AxiosRequest


proc axios*(
  `method`, url: cstring,
  config: AxiosConfig = nil
): Future[AxiosResponse] {.importjs: """
  axios({
    method: #
    url: #,
    config: #})""".}

proc axios*(
  `method`: HttpMethod,
  url: cstring,
  config: AxiosConfig
): Future[AxiosResponse] =
  axios $`method`, url, config
