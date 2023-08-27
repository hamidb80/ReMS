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
    data*: JsObject
    status*: HttpCode
    statusText*: cstring
    headers*: JsObject
    config*: AxiosConfig[JsObject]


proc axios*(
  `method`, url: cstring,
  config: AxiosConfig = nil,
): Future[AxiosResponse] {.importjs: """
  axios({
    method: #,
    url: #,
    config: #})""".}

proc axios*(
  `method`: HttpMethod,
  url: cstring,
  config: AxiosConfig,
): Future[AxiosResponse] =
  axios $`method`, url, config

proc requestFrom(
  methodd, url: cstring,
  form: FormData,
  cfg: AxiosConfig): Future[AxiosResponse] {.importjs: """
  axios[#](#, #, {
    ...#,
    method: "post",
    headers: {'Content-Type': 'multipart/form-data'}
  })
""".}

proc postForm*(
  url: cstring,
  form: FormData,
  cfg: AxiosConfig): Future[AxiosResponse] = 
  requestFrom "post", url, form, cfg

proc putForm*(
  url: cstring,
  form: FormData,
  cfg: AxiosConfig): Future[AxiosResponse] = 
  requestFrom "put", url, form, cfg

proc getApi*(url: cstring): Future[AxiosResponse] 
  {.importjs: "axios.get(@)".}

proc postApi*(url: cstring, data: JsObject = nil): Future[AxiosResponse] 
  {.importjs: "axios.post(@)".}

proc putApi*(url: cstring, data: JsObject = nil): Future[AxiosResponse] 
  {.importjs: "axios.put(@)".}
