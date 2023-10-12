import std/[nativesockets, threadpool, os]

import ./[server, bot, config]
import utils/db_init


when isMainModule:
    echo "started ..."
    
    discard existsOrCreateDir appSaveDir
    initDb()

    echo "initilization completed ..."
    echo "GO ..."

    spawn runBaleBot baleBotToken
    runWebServer Port webServerPort

