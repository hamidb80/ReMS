import std/[nativesockets, threadpool, os]

import ./[server, bot, config]
import ./utils/db_init


when isMainModule:
    echo "init directories"
    discard existsOrCreateDir appSaveDir

    echo "init DB"
    initDb()

    let params = commandLineParams()

    if "--bale" in params:
        spawn runBaleBot baleBotToken

    echo "Run on port: ", webServerPort
    runWebServer Port webServerPort
