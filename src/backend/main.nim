import std/[nativesockets, threadpool, os]

import ./[server, config]
import ./extensions/bot
import ./utils/db_init
import ../common/package


when isMainModule:
    echo "..:: ReMS - v", packageVersion, " ::.."

    echo "init directories"
    discard existsOrCreateDir appSaveDir

    echo "init DB"
    initDb()

    let params = commandLineParams()

    if "--bale" in params:
        spawn runBaleBot baleBotToken
        echo "Bale bot started ..."


    const host =
        when defined localhost: "localhost"
        else: "0.0.0.0"

    echo "Run on http://", host, ':', webServerPort
    runWebServer host, Port webServerPort
