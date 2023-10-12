import std/[nativesockets, threadpool, os]

import ./[server, bot, config]
import ./utils/db_init


when isMainModule:
    echo "init directories"
    discard existsOrCreateDir appSaveDir
    
    echo "init DB"
    initDb()

    echo "Run on port: ", webServerPort
    spawn runBaleBot baleBotToken
    runWebServer Port webServerPort

