import std/tables

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
        "fonts.google.css": "https://fonts.googleapis.com/css2?family=Mooli&family=Vazirmatn:wght@400&family=Ubuntu+Mono&display=swap"
    }


when isMainModule:
    import std/[httpclient, os]

    let c = newHttpClient()

    for d, url in extdeps:
        let path = "./assets/lib/" & d
        if not fileExists path:
            downloadFile c, url, path
            echo "+ ", path
