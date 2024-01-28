import std/[nativesockets, threadpool, os]

import ./[server, bot, config]
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

    echo "Run on port: ", webServerPort
    runWebServer Port webServerPort
