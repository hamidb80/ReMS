import std/[tables]

const
    extdeps* = toTable {
        "lib.konva.js": "https://unpkg.com/konva@9.3.3/konva.min.js",
        "lib.axios.js": "https://unpkg.com/axios@1.6.7/dist/axios.min.js",
        "lib.font-observer.js": "https://unpkg.com/fontfaceobserver@2.3.0/fontfaceobserver.standalone.js",

        "lib.katex.js": "https://unpkg.com/katex@0.16.9/dist/katex.min.js",
        "lib.katex.css": "https://unpkg.com/katex@0.16.9/dist/katex.min.css",

        "theme.bootstrap.css": "https://bootswatch.com/5/litera/bootstrap.min.css",
        "icons.boostrap.css": "https://unpkg.com/bootstrap-icons@1.11.3/font/bootstrap-icons.min.css",
        "icons.fontawesome.css": "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css",
        "fonts.google.css": "https://fonts.googleapis.com/css2?family=Mooli&family=Vazirmatn:wght@400&family=Ubuntu+Mono&display=swap",

        "lib.unpoly.js":  "https://cdn.jsdelivr.net/npm/unpoly@3.8.0/unpoly.min.js",
        "lib.unpoly.css": "https://cdn.jsdelivr.net/npm/unpoly@3.8.0/unpoly.min.css",
    }

when isMainModule:
    assert defined(externalDeps) or defined(allInternal)

when defined externalDeps:
    import std/[httpclient, os]
    # XXX why importing this cuases linker error here but not in html.nim ?
    # import ../../backend/routes

    let c = newHttpClient()

    for d, url in extdeps:
        let path = "./assets/lib/" & d
        # let path = get_dist_url d
        if not fileExists path:
            echo "+ ", path
            downloadFile c, url, path

when defined allInternal:
    import std/[httpclient, strformat, strutils, nre, uri, os]

    let c = newHttpClient()

    func removeUrlQuery(s: string): string =
        s.split("?")[0]

    var filesToDownload: seq[tuple[url: Uri, path: string]]
    const libDir = "./assets/lib/"

    for d, assetUrl in extdeps:
        let assetPath = libDir & d

        if not fileExists assetPath:
            echo "+ ", assetUrl

            if assetPath.endsWith ".css":
                let content = c.getContent assetUrl

                proc repl(match: RegexMatch): string =
                    let
                        suburl = removeUrlQuery strip(match.captures[0],
                                chars = {'"', '\''})
                        absUrl =
                            if "://" in suburl: parseuri suburl
                            else: assetUrl.splitPath.head.parseuri / suburl
                        fname = suburl.splitPath.tail
                        localPath = "./assets/lib/" & fname
                        localUrl = "/dist/?file=/lib/" & fname

                    add filesToDownload, (absUrl, localPath)
                    fmt"url({localUrl})"

                writeFile assetPath, content.replace(
                    re"""url\(([a-zA-Z0-9\/.:"?_-]+)\)""", repl)

            else:
                downloadFile c, assetUrl, assetPath

    for (url, path) in filesToDownload:
        if not fileExists path:
            echo "+ ", url
            downloadFile c, url, path
